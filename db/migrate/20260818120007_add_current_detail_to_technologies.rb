class AddCurrentDetailToTechnologies < ActiveRecord::Migration[8.1]
  def change
    add_reference :technologies,
                  :current_detail,
                  foreign_key: { to_table: :technology_details },
                  null: true
  end
end
