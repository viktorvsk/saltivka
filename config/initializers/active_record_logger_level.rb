ActiveRecord::Base.logger.level = ENV.fetch("ACTIVE_RECORD_LOG_LEVEL", "warn").to_sym
