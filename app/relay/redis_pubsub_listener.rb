class RedisPubsubListener
  attr_reader :channels, :redis_thread, :redis

  def initialize(server_events_handler)
    @channels = []
    @redis = Redis.new(url: ENV["REDIS_URL"])
    @redis_thread = nil
    @server_events_handler = server_events_handler
  end

  def remove_channel(pubsub_id)
    channels.delete("events:#{pubsub_id}")
    unsubscribe
    subscribe
  end

  def add_channel(pubsub_id)
    channels.push("events:#{pubsub_id}")
    unsubscribe
    subscribe
  end

  def unsubscribe
    redis&.unsubscribe if redis.subscribed?
    redis_thread&.exit
  end

  private

  def subscribe
    if channels.empty?
      @redis_thread = nil
      return
    end

    loop { redis.subscribed? ? redo : break }

    @redis_thread = Thread.new do
      redis.subscribe(channels) do |on|
        on.message do |channel, event|
          @server_events_handler.call(channel, event)
        end
      end
    end
  end
end
