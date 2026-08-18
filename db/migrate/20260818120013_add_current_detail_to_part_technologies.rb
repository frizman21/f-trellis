class AddCurrentDetailToPartTechnologies < ActiveRecord::Migration[8.1]
  def change
    add_reference :part_technologies,
                  :current_detail,
                  foreign_key: { to_table: :part_technology_details },
                  null: true
  end
end
