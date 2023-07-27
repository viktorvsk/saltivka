if ActiveRecord::Type::Boolean.new.cast(ENV["ACTIVE_RECORD_LOG_SLOW_QUERIES"])
  require "slow_query_logger"

  logger = SlowQueryLogger.new($stdout, ENV.fetch("ACTIVE_RECORD_SLOW_QUERIES_THRESHOLD", 1000).to_i)

  ActiveSupport::Notifications.subscribe("sql.active_record", logger)
end
