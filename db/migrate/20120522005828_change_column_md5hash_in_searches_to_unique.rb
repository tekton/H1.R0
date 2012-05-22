class ChangeColumnMd5hashInSearchesToUnique < ActiveRecord::Migration
  def change
    add_index :searches, :md5hash, :unique=> true
  end
end
