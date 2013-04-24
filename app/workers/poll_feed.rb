class PollFeed
  include Sidekiq::Worker
  sidekiq_options :queue => :poll
  def perform(id)

    feed = Feed.find id
    url = feed.current_feed_url || feed.feed_url
    response = FetchFeedService.perform(url)
    feed.update_column(:current_feed_url, response.url)
    feed.update_column(:etag, response.etag)
    feed.touch(:fetched_at)
    feed.increment! :fetch_count

    case response.status
      when 200
        if response.body && response.body.present?
          feed.update_column(:document_text, response.body)
          unless feed.destroyed?
            process_feed(id)
            #self.class.requeue_polling(id)
          end

        end
    end

  rescue Errno::EMFILE
    #let this raise, skip incrementing connection_errors
    ObjectSpace.each_object(File) do |f|
      puts "%s: %d" % [f.path, f.fileno] unless f.closed?
    end
    raise $!
  rescue ArgumentError
    Rails.logger.debug "Poll Feed failed: #{feed.feed_url} - #{feed.name}"
    feed.increment! :parse_errors
  rescue
    Rails.logger.debug "Poll Feed failed: #{feed.feed_url} - #{feed.name}"
    feed.increment! :connection_errors
  end

  def process_feed(id)
    ProcessFeed.perform_async(id)
  end

  def self.requeue_polling(id)
    PollFeed.perform_in(Reader::UPDATE_FREQUENCY.minutes, id) unless poll_scheduled?(id)
  end

  def self.poll_scheduled?(id)
    r = Sidekiq::ScheduledSet.new
    jobs = r.select { |job| job.item["class"] == "PollFeed" && job.item["args"][0] == id }
    !jobs.empty?
  end
end
