class AddCurrentDetailToParts < ActiveRecord::Migration[8.1]
  def change
    add_reference :parts,
                  :current_detail,
                  foreign_key: { to_table: :part_details },
                  null: true
  end
end
