module ScholarsHelper
  def since(scholar)
    "Since #{scholar.scraped_at.year - 5}" if scholar.scraped_at && scholar.citations
  end
end
