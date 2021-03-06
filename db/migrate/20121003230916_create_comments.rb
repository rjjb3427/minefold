class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.references :server
      t.references :author
      t.text :body

      t.timestamps
    end
    
    add_index :comments, :server_id
    add_index :comments, :author_id
  end
end
