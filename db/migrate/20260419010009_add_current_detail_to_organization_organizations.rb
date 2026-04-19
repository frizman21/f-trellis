class AddCurrentDetailToOrganizationOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_reference :organization_organizations,
                  :current_detail,
                  foreign_key: { to_table: :organization_organization_details },
                  null: true,
                  index: { name: "index_oo_on_current_detail" }
  end
end
