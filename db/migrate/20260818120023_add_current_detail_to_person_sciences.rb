class AddCurrentDetailToPersonSciences < ActiveRecord::Migration[8.1]
  def change
    add_reference :person_sciences,
                  :current_detail,
                  foreign_key: { to_table: :person_science_details },
                  null: true
  end
end
