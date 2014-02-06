class CreateCcbConfigs < ActiveRecord::Migration
  def change
    create_table :ccb_configs do |t|
      t.string :subdomain
      t.string :encrypted_api_user
      t.string :encrypted_api_password

      t.timestamps
    end
    add_index :ccb_configs, :subdomain, unique: true
  end
end
