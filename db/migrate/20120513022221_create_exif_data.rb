class CreateExifData < ActiveRecord::Migration
  def change
    create_table :exif_data do |t|
      t.integer :parent
      t.string :tag
      t.string :value

      t.timestamps
    end
  end
end
