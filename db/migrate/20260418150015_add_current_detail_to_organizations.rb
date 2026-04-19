class AddCurrentDetailToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_reference :organizations, :current_detail, foreign_key: { to_table: :organization_details }, null: true
  end
end
