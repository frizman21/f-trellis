class CreateSciences < ActiveRecord::Migration[8.1]
  def change
    create_table :sciences do |t|
      t.timestamps
    end
  end
end
