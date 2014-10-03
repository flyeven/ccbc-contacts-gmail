class AddFamilyIdToIndividuals < ActiveRecord::Migration
  def change
    add_column :individuals, :family_id, :integer
    add_index :individuals, :family_id
  end
end
