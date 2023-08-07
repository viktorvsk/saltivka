class Admin::LatestEventsController < AdminController
  def show
    @latest_events = MemStore.latest_events.map { |e| JSON.parse(e) }
  end
end
