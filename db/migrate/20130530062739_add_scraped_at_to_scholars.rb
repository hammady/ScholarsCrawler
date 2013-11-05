class AddScrapedAtToScholars < ActiveRecord::Migration
  def change
    add_column :scholars, :scraped_at, :datetime
  end
end
