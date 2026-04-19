class AddCurrentDetailToPartParts < ActiveRecord::Migration[8.1]
  def change
    add_reference :part_parts,
                  :current_detail,
                  foreign_key: { to_table: :part_part_details },
                  null: true
  end
end
