class ChangeOptionsToTextInUsers < ActiveRecord::Migration
  def change
    change_column :users, :options, :text
  end
end
