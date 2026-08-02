class CreatePartSpecificationParameters < ActiveRecord::Migration[8.0]
  def change
    # What a part type is measured by. A PartType already carries
    # `additional_attribute_keys`, but a bare key cannot say that weight is a
    # number in pounds — so "12 lbs" lands in the property bag as a string, two
    # runs writing "12lb" and "12 lbs" look like different facts, and nothing can
    # sort parts by weight or compare pounds against kilograms. The data model
    # spec calls this out: a value needing richer structure is a signal to
    # promote it out of the bag, not to nest inside it.
    #
    # A part carries several types, so a part that is both a Physical Part and an
    # Electrical Component is measured by both sets. That is the whole
    # inheritance mechanism — no hierarchy needed.
    create_table :part_type_parameters do |t|
      t.references :part_type, null: false, foreign_key: true
      t.string :name, null: false
      # The unit every value of this parameter is stored in. Values arrive
      # converted into it, which is what makes two parts comparable. NULL for a
      # text parameter, which has no unit.
      t.string :unit
      t.string :value_type, null: false, default: "number"
      t.text :description
      t.timestamps

      t.index [ :part_type_id, :name ], unique: true, name: "index_part_type_parameters_on_type_and_name"
    end

    # One measured value, on one PartDetail. Not a Detail itself: it is part of
    # the assertion the PartDetail makes, so it inherits that row's `as_of` and
    # its `source_processing_report`. A page fetched again makes a new PartDetail
    # with a new set of these, so the append-only rule still holds.
    create_table :part_detail_parameters do |t|
      t.references :part_detail, null: false, foreign_key: true
      t.references :part_type_parameter, null: false, foreign_key: true
      t.decimal :value_number, precision: 20, scale: 6
      t.string :value_text
      # What the page actually said, before conversion — "5.6 kg" for a
      # parameter measured in pounds. Converting is the only way to make values
      # comparable, and keeping the original is the only way to see a bad
      # conversion afterwards.
      t.string :as_stated
      t.integer :confidence_tenths
      t.timestamps

      t.index [ :part_detail_id, :part_type_parameter_id ], unique: true,
              name: "index_part_detail_parameters_on_detail_and_parameter"
    end
  end
end
