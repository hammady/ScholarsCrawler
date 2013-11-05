class Scholar < ActiveRecord::Base
  attr_accessible :id, :name, :google_scholar_id, :dblp_author_id
  attr_accessible :citations, :hindex, :i10index, :recent_citations, :recent_hindex, :recent_i10index
  attr_accessible :current_position, :phd_from, :phd_year, :last_institution, :last_job

  has_many :scholar_venues, dependent: :destroy, order: "count desc"
  has_many :venues, through: :scholar_venues

  def scrape
    scraper = GoogleScholarScraper.new
    ret1 = scraper.get_scholar_citations(self)
    ret2 = scraper.get_dblp_info(self)
    if ret1 || ret2
      self.save
    else
      return nil
    end
  end

  def to_s
    self.name
  end

  def image_url
    "http://scholar.google.com/citations?view_op=view_photo&user=#{self.google_scholar_id}"
  end

  def self.update_all
    not_done = true
    GoogleScholarScraper.new.update_all(Scholar.all) do
      logger.debug "Updated scholars successfully"
      not_done = false
    end
    while not_done
      sleep(1)
    end
  end

  def self.to_csv(options = {})
    CSV.generate(options) do |csv|
      csv << column_names
      all.each do |scholar|
        csv << scholar.attributes.values_at(*column_names)
      end
    end
  end

  def phd
    if phd_year && phd_year > 0
      "#{phd_from} (#{phd_year})"
    else
      "#{phd_from}"
    end
  end
end
