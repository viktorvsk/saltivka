Rails.configuration.after_initialize do
  RELAY_CONFIG = RelayConfig.new # standard:disable Lint/ConstantDefinitionInBlock
end
