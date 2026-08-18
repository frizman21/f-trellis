class AddCurrentDetailToContractPeople < ActiveRecord::Migration[8.1]
  def change
    add_reference :contract_people,
                  :current_detail,
                  foreign_key: { to_table: :contract_person_details },
                  null: true
  end
end
