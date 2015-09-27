class ChangeExifImageIdToInteger < ActiveRecord::Migration
  def up
    execute "ALTER TABLE exif_data ALTER COLUMN image_id TYPE integer USING image_id::integer";
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The string is now an int, can't go back..."
  end
end
