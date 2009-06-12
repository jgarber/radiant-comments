class AddPosition < ActiveRecord::Migration
  def self.up
    add_column :comments, :position, :integer, :null => false
  end

  def self.down
    remove_column :comments, :position
  end
end