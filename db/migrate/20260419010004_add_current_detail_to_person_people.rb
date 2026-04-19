class AddCurrentDetailToPersonPeople < ActiveRecord::Migration[8.1]
  def change
    add_reference :person_people,
                  :current_detail,
                  foreign_key: { to_table: :person_person_details },
                  null: true
  end
end
