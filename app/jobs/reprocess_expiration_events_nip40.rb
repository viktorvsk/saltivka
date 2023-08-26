class ReprocessExpirationEventsNip40
  include Sidekiq::Worker
  sidekiq_options queue: "nostr.nip40"

  def perform
    Event.where("jsonb_path_query_array(tags, '$[*][0]') ? 'expiration'").find_each do |event|
      Event.transaction do
        expiration_tag = event.tags.find { |t| t.first === "expiration" }
        expires_at = expiration_tag.last

        if Time.at(expires_at.to_i).past?
          event.destroy
        else
          event_scheduled = Sidekiq::ScheduledSet.new.any? { |job| job.klass == "DeleteExpiredEventNip40" && job.args.first == event.sha256 }
          DeleteExpiredEventNip40.perform_at(expires_at, sha256) unless event_scheduled
        end
      end
    end
  end
end
