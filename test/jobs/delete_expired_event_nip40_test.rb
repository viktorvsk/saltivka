require "test_helper"

class DeleteExpiredEventNip40Test < ActiveSupport::TestCase
  test "Deletes event by id" do
    event = create(:event)
    DeleteExpiredEventNip40.new.perform(event.sha256)
    refute Event.where(id: event.id).exists?
  end
end
