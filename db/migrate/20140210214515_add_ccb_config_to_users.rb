class AddCcbConfigToUsers < ActiveRecord::Migration
  def change
    add_column :users, :ccb_config_id, :integer
  end
end
