class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.timestamps
    end
  end
end
