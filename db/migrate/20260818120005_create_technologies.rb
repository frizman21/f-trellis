class CreateTechnologies < ActiveRecord::Migration[8.1]
  def change
    create_table :technologies do |t|
      t.timestamps
    end
  end
end
