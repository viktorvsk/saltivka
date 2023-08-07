class Api::EventsController < ApplicationController
  def index
    filters = if params[:req].present?
      JSON.parse(params[:req])[2..]
    elsif params[:filters].present?
      JSON.parse(params[:filters])
    else
      [{}]
    end

    union = filters.map { |filter_set| "(#{Event.by_nostr_filters(filter_set).to_sql})" }.join("\nUNION\n")

    @events = Event.includes(:author).where(id: Event.find_by_sql(union).pluck(:id))
    render json: @events
  end

  def show
    @event = Event.where(id: Event.select(:id).where("LOWER(sha256) = ?", params[:id]))
    render json: @event
  end
end
