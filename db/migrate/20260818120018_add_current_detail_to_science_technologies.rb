class AddCurrentDetailToScienceTechnologies < ActiveRecord::Migration[8.1]
  def change
    add_reference :science_technologies,
                  :current_detail,
                  foreign_key: { to_table: :science_technology_details },
                  null: true
  end
end
