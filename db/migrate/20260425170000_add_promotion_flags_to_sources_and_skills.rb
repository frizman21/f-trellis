class AddPromotionFlagsToSourcesAndSkills < ActiveRecord::Migration[8.1]
  def change
    add_column :sources, :is_promotable, :boolean, null: false, default: false
    add_column :sources, :is_fixtured,   :boolean, null: false, default: false
    add_index  :sources, [:is_promotable, :is_fixtured]

    add_column :skills, :is_promotable, :boolean, null: false, default: false
    add_column :skills, :is_fixtured,   :boolean, null: false, default: false
    add_index  :skills, [:is_promotable, :is_fixtured]
  end
end
