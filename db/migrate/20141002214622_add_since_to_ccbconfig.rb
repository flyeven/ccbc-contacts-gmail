class AddSinceToCcbconfig < ActiveRecord::Migration
  def change
    add_column :ccb_configs, :since, :date
  end
end
