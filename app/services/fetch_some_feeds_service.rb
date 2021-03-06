
module Typhoeus
  class Request
    attr_accessor :feed
  end
end

class FetchSomeFeedsService

  attr_accessor :hydra

  def initialize
    raise "Deprecated"
  end

  def self.perform(ids)
    self.new.perform(ids)
  end

  def perform(ids)
    Typhoeus::Config.verbose = true
    @hydra = Typhoeus::Hydra.new(max_concurrency: 200)
    Feed.where(:id => ids).each do |feed|
      Rails.logger.debug "Fetching #{feed.feed_url} - #{feed.name}"
      hydra.queue request_for(feed)
    end

    hydra.run
  end

  def request_for(feed)
    url = feed.current_feed_url || feed.feed_url
    request = Typhoeus::Request.new(url, ssl_verifypeer: false, ssl_verifyhost: 2, timeout: 60, followlocation: true, maxredirs: 5, accept_encoding: "gzip")
    request.feed = feed
    request.on_complete do |response|
      handle_response response
    end
    request
  end

  def handle_response(response)
    feed = response.request.feed
    feed.increment! :fetch_count
    puts "#{Time.current}: #{response.code} - #{feed.id} - #{feed.name} - #{response.effective_url}"
    case response.response_code
    when 200
      feed.save_document response.body
      unless feed.destroyed?
        feed.update_attribute(:current_feed_url, response.effective_url)
        feed.update_attribute(:etag, response.headers["etag"])
        ProcessFeed.perform_async(feed.id)
      end

    else
      Rails.logger.debug "Fetch failed: #{feed.feed_url} - #{feed.name}"
      feed.increment! :connection_errors
    end
  end
end
