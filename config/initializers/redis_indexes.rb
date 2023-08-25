Rails.application.config.after_initialize do
  if ENV["BUILD_STEP"].blank?
    begin
      MemStore.with_redis do |redis|
        redis.pipelined do |pipeline|
          pipeline.select("0")
          pipeline.call(RedisSearchCommands::CREATE_SCHEMA_COMMAND.split(" "))
        end
      end
    rescue RedisClient::CommandError => e
      if e.message != "Index already exists"
        raise(e)
      end
    end
  end
end
