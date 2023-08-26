# frozen_string_literal: true

require "clockwork"
require "./config/boot"
require "./config/environment"

module Clockwork
  every(30.minutes, "Cleanup connections data") { CleanupConnections.perform_async }
  every(30.minutes, "Cleanup requests:<IP> data used for rate limiting") { CleanupRequests.perform_async }
  every(2.hours, "Reprocess expirable events (NIP-40)") { ReprocessExpirationEventsNip40.perform_async }
end
