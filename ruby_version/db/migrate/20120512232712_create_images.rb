class CreateImages < ActiveRecord::Migration
  def change
    create_table :images, :primary_key => :id do |t|
      t.integer :id
      t.string :location
      t.string :name
      
      t.timestamps
    end
  end
end
