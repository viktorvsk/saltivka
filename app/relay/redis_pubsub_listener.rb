class RedisPubsubListener
  attr_reader :channels, :redis_thread, :redis, :callback

  def initialize(callback)
    @channels = []
    @redis = Redis.new
    @redis_thread = nil
    @callback = callback
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

    @redis_thread = Thread.new do
      redis.subscribe(channels) { |on| callback.call(on) }
    end
  end
end
