class CreateSkillRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table :skill_revisions do |t|
      t.references :skill, null: false, foreign_key: true
      t.string :content

      t.timestamps
    end
  end
end
