class ScholarVenue < ActiveRecord::Base
  attr_accessible :count, :venue_id

  belongs_to :scholar
  belongs_to :venue

  def name
    venue.name
  end

  def to_s
    "#{venue.name} (#{count})"
  end
end
