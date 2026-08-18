class AddCurrentDetailToContractParts < ActiveRecord::Migration[8.1]
  def change
    add_reference :contract_parts,
                  :current_detail,
                  foreign_key: { to_table: :contract_part_details },
                  null: true
  end
end
