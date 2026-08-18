class AddCurrentDetailToOrganizationTechnologies < ActiveRecord::Migration[8.1]
  def change
    add_reference :organization_technologies,
                  :current_detail,
                  foreign_key: { to_table: :organization_technology_details },
                  null: true
  end
end
