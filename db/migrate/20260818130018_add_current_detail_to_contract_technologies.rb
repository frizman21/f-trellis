class AddCurrentDetailToContractTechnologies < ActiveRecord::Migration[8.1]
  def change
    add_reference :contract_technologies,
                  :current_detail,
                  foreign_key: { to_table: :contract_technology_details },
                  null: true
  end
end
