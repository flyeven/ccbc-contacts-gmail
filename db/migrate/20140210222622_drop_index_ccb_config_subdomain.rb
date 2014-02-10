class DropIndexCcbConfigSubdomain < ActiveRecord::Migration
  def change
    remove_index :ccb_configs, column: :subdomain
  end
end
