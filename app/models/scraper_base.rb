class ScraperBase

  def initialize(log_file = 'scraper.log', content_dir = 'contents')
    @site_id = 'UNKNOWN'
    @pending_requests = 0
    @done_requests = 0
    @max_parallel_refpages = 10
    # During capybara tests (stubbed Typheous, no cache), hydra stops processing queue on reaching @max_parallel_articles!
    #@max_parallel_articles = 20
    @max_parallel_articles = 50
    @max_hydra_queue_length = 200

    @hydra_articles = Typhoeus::Hydra.new(:max_concurrency => @max_parallel_articles)

    @logger = Logger.new(STDOUT)
    @logger.level = Rails.logger.level
    @logger.progname = log_file # TODO: this doesn't work, need to figure out why

    @stop_on_seen_page = true
    @content_dir = Rails.root.join(ENV['WRITABLE_DIR']).join(content_dir)
    Dir.mkdir(@content_dir) unless File.directory?(@content_dir)
	end
	
	def self.saveResultsToFile(fileName, results)
		begin
      f = File.new(fileName, 'w')
      results.force_encoding("utf-8") # HACK! SHOULD GET CORRECT ENCODING
      f.write(results)
    rescue => e
      $stderr.puts "Could not save file #{fileName}"
      $stderr.puts e
    ensure
      f.close
    end
	end

	def ScraperBase.read_file(fileName)
		f = File.new(fileName, 'r')
		c = f.read()
		f.close()
		c.each_line do |l|
		  yield l.chomp!
		end
	end

  def pline(line, newline = false)
    print "\r#{line}"
    print " " * 30
    print "\n" if newline
    $stdout.flush
  end
  
	def scrape(search_type, enable_cache = true)
    @enable_cache = enable_cache
    puts "Scraping as #{self.class.name}"
    t1 = Time.now
	  case search_type
    when :topic
  	  page = get_start_page
      iterate_list_pages(page) {|item, isnew| yield item, isnew if block_given?}
    when :ref
      iterate_input_items {|item, isnew| yield item, isnew if block_given?}
    when :manual
      iterate_manual_entries {|item, isnew| yield item, isnew if block_given?}
    end
    tdiff = Time.now - t1
    pline "FINISHED #{@done_requests} requests in #{tdiff.round} seconds (#{@done_requests/tdiff} r/s)", true
	end
	
  def iterate_list_pages(page)
    @total = total_pages page
    puts "Total results: #{@total}"
    @curr_property = 1
    @curr_page = 1
    while page != nil
      pline "\nProcessing page #{@curr_page}...", true
      new_items_found = process_list_page(page) do |item, isnew|
        yield item, isnew
      end
      if new_items_found or (new_items_found == false and not @stop_on_seen_page)
        #page.save_as("list#{@curr_page}.html")
        @curr_page = @curr_page + 1
        if max_pages_to_scrape == 0 or @curr_page <= max_pages_to_scrape
          url = get_next_page_link(page)
          if url
            #page = @agent.get(url)
            page = Typhoeus::Request.get(url)
          else
            page = nil
          end
        else
          puts "\nStopping at this page, enough results!"
          page = nil
        end
      else
        puts "\nNo new items found on this page, stopping!"
        page = nil
      end
    end
  end
  
  def self.node_text(page, xpath)
    n = page.at(xpath)
    n = n.text.strip if n
  end
  
  def self.node_html(page, xpath)
    n = page.at(xpath)
    n = n.inner_html.strip if n
  end
  
  def self.to_date(year, month = 1, day = 1)
    day = 1 if day.blank?
    month = 1 if month.blank?
    return nil if year.blank? or year.to_s.to_i <= 0
    begin
      "#{year}-#{month}-#{day}".to_date
    rescue
      begin
        "#{year}-#{month}-1".to_date
      rescue
        begin
          "#{year}-1-1".to_date
        rescue
          nil
        end
      end
    end
  end
  
  # functions to override in subclasses

  def get_start_page
    raise 'Not implemented'
  end
  
  def max_pages_to_scrape
    0
  end
  
  def results_per_page
    raise 'Not implemented'
  end
  
  def total_pages(page)
    'Unknown'
  end
  
  def get_next_page_link
    raise 'Not implemented'
  end
  
  def process_list_page
    raise 'Not implemented'
  end
  
  def get_detail
    raise 'Not implemented'
  end
  
  def process_detail_page
    raise 'Not implemented'
  end

  def http_get(url)
    @pending_requests += 1
    f = Fiber.current
    http = EventMachine::HttpRequest.new(url).get
    @logger.debug "connections open: #{EventMachine.connection_count}, @pending_requests after: #{@pending_requests}"

    # resume fiber once http call is done
    http.callback { em_stop; f.resume(http) }
    http.errback  { em_stop; f.resume(Exception.new("ERROR IN HTTP REQUEST #{http.inspect}")) }

    return Fiber.yield
  end

  def em_stop
    @pending_requests -= 1
    @logger.debug "@pending_requests in callback: #{@pending_requests}"
    @done_requests += 1
  end

  def hydra_queue(hydra, link, cached_path = nil, yield_exception = false)
    request = Typhoeus::Request.new(link, :followlocation => true)
    if cached_path && @enable_cache
      # look for cached version
      if File.exist? cached_path
        @logger.debug "Cache hit: #{cached_path}"
        # load from file
        yield request, File.read(cached_path)
        return
      end
    end
    request.on_complete do |response|
      if response.success?
        begin
          ScraperBase.saveResultsToFile cached_path, response.body if cached_path
          yield request, response.body
        rescue => e
          @logger.warn "WARNING: Exception while processing response for #{link}"
          @logger.warn e
        end
      elsif response.timed_out?
        # aw hell no
        err = "ERROR: Timed out while requesting #{link}"
        @logger.error err
        yield request, Exception.new(err) if yield_exception
      elsif response.code == 0
        # Could not get an http response, something's wrong.
        err = "ERROR: Unknown error (#{response}) while requesting #{link}"
        @logger.error err
        yield request, Exception.new(err) if yield_exception
      else
        # Received a non-successful http response.
        err = "ERROR: HTTP request failed: #{response.code.to_s} while requesting #{link}"
        @logger.error err
        yield request, Exception.new(err) if yield_exception
      end
      @done_requests += 1
      @logger.debug "---- Hydra has #{hydra.queued_requests.length} queued requests"
    end
    hydra.queue(request)
    @logger.debug "++++ Hydra has #{hydra.queued_requests.length} queued requests"
    # prevent queue from growing too big, thus delaying hydra.run too much
    hydra.run if hydra.queued_requests.length > @max_hydra_queue_length
  end

  def hydra_run(hydra, list)
    list.each do |item|
      yield item
    end
    hydra.run
  end
end
