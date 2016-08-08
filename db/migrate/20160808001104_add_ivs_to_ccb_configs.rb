class AddIvsToCcbConfigs < ActiveRecord::Migration
  def change
    add_column :ccb_configs, :encrypted_api_user_iv, :string
    add_column :ccb_configs, :encrypted_api_password_iv, :string
  end
end
