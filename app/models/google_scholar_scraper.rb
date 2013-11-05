class GoogleScholarScraper < ScraperBase

  def initialize(content_dir = 'scholar-contents')
    super('scholar.log', content_dir)
    @logger.debug "Google Scholar scraper initialized"
  end

  def get_google_scholar_url(mScholar)
    "http://scholar.google.com/citations?user=#{mScholar.google_scholar_id}&hl=en"
  end

  def get_scholar_citations(mScholar)
    url = get_google_scholar_url(mScholar)
    page = Typhoeus::Request.get(url)
    process_google_scholar_citations(url, page.body, mScholar)
    #f = File.open("ihab.html"); xml = Nokogiri::HTML(f); f.close
  end

  def process_google_scholar_citations(url, response, mScholar)
    xml = Nokogiri::HTML.parse(response, url)

    name = ScraperBase.node_text xml, './/span[@id="cit-name-display"]'
    @logger.debug("Found profile with name: #{name}")
    return nil if name.blank?

    mScholar.name = name
    (xml/'//table[@id="stats"]//tr').each do |tr|
      td_caption = tr.at('./td[@class="cit-caption"]')
      #@logger.debug "td_caption is #{td_caption.class} #{td_caption}"
      td_data = td_caption.next_sibling
      case td_caption.text
      when 'Citations'
        mScholar.citations = td_data.text
        mScholar.recent_citations = td_data.next_sibling.text
        #@logger.debug("Citations: #{mScholar.citations}, #{mScholar.recent_citations}")
      when 'h-index'
        mScholar.hindex = td_data.text
        mScholar.recent_hindex = td_data.next_sibling.text
        #@logger.debug("h-index: #{mScholar.hindex}, #{mScholar.recent_hindex}")
      when 'i10-index'
        mScholar.i10index = td_data.text
        mScholar.recent_i10index = td_data.next_sibling.text
        #@logger.debug("i10-index: #{mScholar.i10index}, #{mScholar.recent_i10index}")
      end
    end

    mScholar.scraped_at = Time.now
    mScholar
  end

  def get_dblp_url(mScholar)
    query = mScholar.dblp_author_id.gsub(/\s+/, '+')
    "http://dblp.l3s.de/?q=#{query}"
  end

  def get_dblp_info(mScholar)
    url = get_dblp_url(mScholar)
    page = Typhoeus::Request.get(url)
    process_dblp_info url, page.body, mScholar
    #f = File.open("ihab-dblp.html"); xml = Nokogiri::HTML(f); f.close
  end

  def process_dblp_info(url, response, mScholar)
    xml = Nokogiri::HTML.parse(response, url)

    @logger.debug("Analyzing DBLP venus")

    mScholar.scholar_venues.destroy_all

    (xml/'//div[@class="facet-box-title-gray"]').each do |title_div|
      title = ScraperBase.node_text title_div, './strong'
      if title.start_with? "Venues"
        (title_div/'../div[@class="facet-box-yellow"]/span').each do |detail_span|
          count = ScraperBase.node_text detail_span, './text()'
          unless count.start_with? "More"
            count = count.match(/\(([0-9]+)\)/)[1].to_i
            venue = ScraperBase.node_text detail_span, './a'
            #@logger.debug("Found venue #{venue} count #{count}")
            mVenue = Venue.find_or_create_by_name venue
            mScholar.scholar_venues.build venue_id: mVenue.id, count: count
          end
        end
      end
    end

    mScholar.scraped_at = Time.now
    mScholar
  end

  def update_all(scholars)
    hydra = Typhoeus::Hydra.new(:max_concurrency => 10)
    scholars_done = 0
    hydra_run(hydra, scholars) do |scholar|
      url = get_google_scholar_url(scholar)
      hydra_queue(hydra, url, nil, true) do |request, response|
        unless response.instance_of? Exception
          process_google_scholar_citations(url, response, scholar)
        end
        url = get_dblp_url(scholar)
        hydra_queue(hydra, url, nil, true) do |request, response|
          unless response.instance_of? Exception
            process_dblp_info(url, response, scholar)
          end
          scholar.save
          scholars_done += 1
          yield if scholars_done == scholars.length
        end
      end
    end
  end
end
