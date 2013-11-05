class CreateScholars < ActiveRecord::Migration
  def change
    create_table :scholars do |t|
      t.primary_key :id
      t.string :name
      t.string :google_scholar_id
      t.integer :citations
      t.integer :recent_citations
      t.integer :hindex
      t.integer :recent_hindex
      t.integer :i10index
      t.integer :recent_i10index

      t.timestamps
    end
  end
end
