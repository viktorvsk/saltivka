Rails.application.config.after_initialize do
  initialization = false

  if ENV["BUILD_STEP"].blank?
    begin
      MemStore.with_redis { |c| c.call("FT.INFO", "tmp_subscriptions_idx") }
      MemStore.with_redis { |c| c.call("FT.DROPINDEX", "tmp_subscriptions_idx") }
      Rails.logger.debug("[RedisIndexes] dropped tmp_subscriptions_idx")
    rescue Redis::BaseError => e
      if e.message == "Unknown index name"
        Rails.logger.debug("[RedisIndexes] tmp_subscriptions_idx does not exist")
      else
        raise(e)
      end
    end

    begin
      MemStore.with_redis { |c| c.call("FT.INFO", "subscriptions_idx") }
    rescue Redis::BaseError => e
      if e.message == "Unknown index name"
        Rails.logger.debug("[RedisIndexes] subscriptions_idx does not exist")
        MemStore.with_redis { |c| c.call(RedisSearchCommands::CREATE_SCHEMA_COMMAND.split(" ")) }
        Rails.logger.debug("[RedisIndexes] created subscriptions_idx")
        initialization = true
      else
        raise(e)
      end
    end

    unless initialization

      current_index = MemStore.with_redis { |c| c.call("FT.INFO", "subscriptions_idx") }
      current_attrs = Hash[*current_index]["attributes"]

      cmd = RedisSearchCommands::CREATE_SCHEMA_COMMAND.split(" ")
      cmd[1] = "tmp_subscriptions_idx"

      MemStore.with_redis { |c| c.call(cmd) }
      Rails.logger.debug("[RedisIndexes] created tmp_subscriptions_idx")

      tmp_index = MemStore.with_redis { |c| c.call("FT.INFO", "tmp_subscriptions_idx") }

      tmp_attrs = Hash[*tmp_index]["attributes"]

      MemStore.with_redis { |c| c.call("FT.DROPINDEX", "tmp_subscriptions_idx") }
      Rails.logger.debug("[RedisIndexes] dropped tmp_subscriptions_idx")

      if current_attrs == tmp_attrs
        Rails.logger.debug("[RedisIndexes] tmp_subscriptions_idx is the same as defined in RedisSearchCommands::CREATE_SCHEMA_COMMAND")
      else
        MemStore.with_redis { |c| c.call("FT.DROPINDEX", "subscriptions_idx") }
        MemStore.with_redis { |c| c.call(RedisSearchCommands::CREATE_SCHEMA_COMMAND.split(" ")) }
        Rails.logger.debug("[RedisIndexes] recreated subscriptions_idx")
      end

    end

  end
end
