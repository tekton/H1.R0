class AddBlankBaseToSearches < ActiveRecord::Migration
  def change
    Search.create :md5hash => "d41d8cd98f00b204e9800998ecf8427e"
  end
end
