# frozen_string_literal: true

require "clockwork"
require "./config/boot"
require "./config/environment"

module Clockwork
  every(30.minutes, "Cleanup connections data") { CleanupConnections.perform_async }
end
