class AddSequenceToSkillRevisions < ActiveRecord::Migration[8.1]
  def up
    add_column :skill_revisions, :sequence, :integer, null: false, default: 0
    add_index :skill_revisions, [ :skill_id, :sequence ], unique: true

    SkillRevision.reset_column_information
    Skill.find_each do |skill|
      skill.skill_revisions.order(:created_at, :id).each_with_index do |rev, idx|
        rev.update_column(:sequence, idx)
      end
    end
  end

  def down
    remove_index :skill_revisions, [ :skill_id, :sequence ]
    remove_column :skill_revisions, :sequence
  end
end
