class AddColumnToSearches < ActiveRecord::Migration
  def change
    add_column :searches, :left, :string
  end
end
