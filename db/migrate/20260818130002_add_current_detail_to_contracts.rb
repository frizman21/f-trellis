class AddCurrentDetailToContracts < ActiveRecord::Migration[8.1]
  def change
    add_reference :contracts,
                  :current_detail,
                  foreign_key: { to_table: :contract_details },
                  null: true
  end
end
