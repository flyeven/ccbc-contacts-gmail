class AddCcbIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :ccb_id, :integer
  end
end
