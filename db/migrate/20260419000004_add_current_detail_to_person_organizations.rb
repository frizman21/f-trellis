class AddCurrentDetailToPersonOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_reference :person_organizations,
                  :current_detail,
                  foreign_key: { to_table: :person_organization_details },
                  null: true
  end
end
