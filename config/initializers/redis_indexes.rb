if ENV["BUILD_STEP"].blank?
  begin
    Sidekiq.redis do |c|
      c.pipelined do
        c.select("0")
        c.call(RedisSearchCommands::CREATE_SCHEMA_COMMAND.split(" "))
      end
    end
  rescue RedisClient::CommandError => e
    if e.message != "Index already exists"
      raise(e)
    end
  end
end
