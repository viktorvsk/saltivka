class ReindexLatestEvents
  LATEST_EVENTS_WINDOW = ENV.fetch("LATEST_EVENTS_WINDOW", 7).to_i

  include Sidekiq::Worker

  sidekiq_options queue: "default"

  def perform
    ActiveRecord::Base.connection.execute("DROP INDEX CONCURRENTLY IF EXISTS index_events_on_latest_records")
    ActiveRecord::Base.connection.execute("CREATE UNIQUE INDEX CONCURRENTLY index_events_on_latest_records ON events(created_at DESC, id DESC) WHERE created_at > '#{LATEST_EVENTS_WINDOW.days.ago.to_date}'")
  end
end
