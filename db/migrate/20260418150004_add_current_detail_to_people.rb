class AddCurrentDetailToPeople < ActiveRecord::Migration[8.1]
  def change
    add_reference :people, :current_detail, foreign_key: { to_table: :person_details }, null: true
  end
end
