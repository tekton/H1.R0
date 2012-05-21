class ChangeSerialToTextInSearches < ActiveRecord::Migration
  def up
    execute "ALTER TABLE searches ALTER COLUMN serial TYPE text";
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The string is now an text, can't go back..."
  end
end
