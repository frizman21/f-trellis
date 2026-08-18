class AddCurrentDetailToContractOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_reference :contract_organizations,
                  :current_detail,
                  foreign_key: { to_table: :contract_organization_details },
                  null: true
  end
end
