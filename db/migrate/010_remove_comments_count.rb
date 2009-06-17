class RemoveCommentsCount < ActiveRecord::Migration
  def self.up
    remove_column :pages, :comments_count
  end

  def self.down
    add_column :pages, :comments_count, :integer, :default => 0
    execute "UPDATE pages SET comments_count = 0"
  end
end