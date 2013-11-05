class AddMoreScholarInfo < ActiveRecord::Migration
  def change
    add_column :scholars, :current_position, :string
    add_column :scholars, :phd_from, :string
    add_column :scholars, :phd_year, :int
    add_column :scholars, :last_institution, :string
    add_column :scholars, :last_job, :string
  end
end
