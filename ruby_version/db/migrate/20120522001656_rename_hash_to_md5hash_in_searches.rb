class RenameHashToMd5hashInSearches < ActiveRecord::Migration
  def change
    rename_column :searches, "hash", :md5hash
  end
end
