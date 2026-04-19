class AddCurrentDetailToPartOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_reference :part_organizations,
                  :current_detail,
                  foreign_key: { to_table: :part_organization_details },
                  null: true
  end
end
