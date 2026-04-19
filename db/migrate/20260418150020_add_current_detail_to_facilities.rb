class AddCurrentDetailToFacilities < ActiveRecord::Migration[8.1]
  def change
    add_reference :facilities, :current_detail, foreign_key: { to_table: :facility_details }, null: true
  end
end
