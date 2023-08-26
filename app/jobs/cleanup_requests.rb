class CleanupRequests
  include Sidekiq::Worker
  sidekiq_options queue: "default"

  def perform
    MemStore.with_redis do |redis|
      requests = redis.keys("requests:*")
      redis.pipelined do |pipeline|
        requests.each { |r| redis.zremrangebyscore(r, "-inf", RELAY_CONFIG.rate_limiting_sliding_window.seconds.ago.to_i.to_s) }
      end
    end
  end
end
