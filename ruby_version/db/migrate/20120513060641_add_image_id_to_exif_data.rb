class AddImageIdToExifData < ActiveRecord::Migration
  def change
    add_column :exif_data, :image_id, :string
  end
end
