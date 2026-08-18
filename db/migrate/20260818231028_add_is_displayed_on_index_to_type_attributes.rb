# Which of a type's attributes appear as columns on its list. See #25.
#
# Defaults to true: a newly defined attribute is almost always one you want to
# see, and a list that starts useful and gets trimmed beats one that starts
# empty and has to be assembled.
class AddIsDisplayedOnIndexToTypeAttributes < ActiveRecord::Migration[8.1]
  def change
    add_column :entity_type_attributes, :is_displayed_on_index, :boolean, null: false, default: true
    add_column :relationship_type_attributes, :is_displayed_on_index, :boolean, null: false, default: true
  end
end
