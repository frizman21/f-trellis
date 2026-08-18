class AddCurrentDetailToSciences < ActiveRecord::Migration[8.1]
  def change
    add_reference :sciences,
                  :current_detail,
                  foreign_key: { to_table: :science_details },
                  null: true
  end
end
