class RedisSearchCommands
  CREATE_SCHEMA_COMMAND = <<~REDIS
    FT.CREATE subscriptions_idx
    ON JSON
    PREFIX 1 subscriptions:
    SCHEMA $.kinds AS kinds TAG
           $.ids AS ids TAG
           $.authors AS authors TAG
           $.tags AS tags TAG
           $.since AS since NUMERIC SORTABLE
           $.until AS until NUMERIC SORTABLE
  REDIS
end
