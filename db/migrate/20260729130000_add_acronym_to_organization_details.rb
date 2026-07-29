class AddAcronymToOrganizationDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :organization_details, :acronym, :string
  end
end
