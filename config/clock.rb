# frozen_string_literal: true

require "clockwork"
require "./config/boot"
require "./config/environment"

module Clockwork
  every(30.minutes, "Cleanup connections data") { CleanupConnections.perform_async }
  every(30.minutes, "Cleanup requests:<IP> data used for rate limiting") { CleanupRequests.perform_async }
  every(2.hours, "Reprocess expirable events (NIP-40)") { ReprocessExpirationEventsNip40.perform_async }
  every(1.day, "Reprocess seen-events", at: "00:00", tz: "UTC") { ReprocessSeenEvents.perform_async }
  every(ReindexLatestEvents::LATEST_EVENTS_WINDOW.days, "Update index_events_on_latest_records INDEX", at: "00:00", tz: "UTC", skip_first_run: true) { ReindexLatestEvents.perform_async }
end
