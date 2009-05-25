class AddRatings < ActiveRecord::Migration
  add_column :comments, :rating, :integer
end
