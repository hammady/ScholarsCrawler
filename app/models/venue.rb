class Venue < ActiveRecord::Base
  attr_accessible :name

  has_many :scholars, through: :scholar_venues
end
