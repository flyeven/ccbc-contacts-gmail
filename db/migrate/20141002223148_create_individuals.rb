class CreateIndividuals < ActiveRecord::Migration
  def change
    create_table :individuals do |t|
      t.integer :ccb_config_id
      t.integer :individual_id
      t.text :object_json
    end
    add_index :individuals, [:ccb_config_id, :individual_id]
  end
end
