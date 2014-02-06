class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :md5
      t.text :authorization
      t.date :since
      t.boolean :recurring

      t.timestamps
    end
    add_index :users, :email
    add_index :users, :md5
  end
end
