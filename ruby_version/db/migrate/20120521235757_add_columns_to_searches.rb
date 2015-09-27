class AddColumnsToSearches < ActiveRecord::Migration
  def change
    add_column :searches, :new_tag, :string
    add_column :searches, :new_val, :string
  end
end
