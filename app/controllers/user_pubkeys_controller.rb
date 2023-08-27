class UserPubkeysController < ApplicationController
  skip_before_action :require_login, only: %i[show]

  def create
    author = begin
      Author.select(:id, :pubkey).where("LOWER(authors.pubkey) = ?", params[:pubkey]).first_or_create(pubkey: params[:pubkey])
    rescue ActiveRecord::RecordNotUnique
      Author.select(:id, :pubkey).where("LOWER(authors.pubkey) = ?", params[:pubkey]).first
    end
    @user_pubkey = author.user_pubkey || current_user.user_pubkeys.new(author: author)
    @user_pubkey.user = current_user
    @auth_event = begin
      event_params = JSON.parse(params[:signature])
      event_params["sha256"] = event_params.delete("id")
      Event.new(event_params)
    rescue
      Event.new
    end
    challenge_tag = @auth_event.tags.find { |t| t.first == "challenge" }

    MemStore.connect(cid: current_user.email)

    if @auth_event.valid? &&
        @user_pubkey.valid? &&
        @auth_event.pubkey == @user_pubkey.pubkey &&
        challenge_tag&.second == current_user.email &&
        @user_pubkey.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to edit_user_path, notice: "Successfully connected new Nostr account" }
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_user_path, alert: "Public key was not connected because of errors: #{[@auth_event.errors.full_messages, @user_pubkey.errors.full_messages].flatten.join(", ")}" }
        format.turbo_stream do
          flash.now[:alert] = "Public key was not connected because of errors: #{[@auth_event.errors.full_messages, @user_pubkey.errors.full_messages].flatten.join(", ")}"
        end
      end
    end
  ensure
    MemStore.disconnect(cid: current_user.email)
  end

  def show
    user_pubkey = UserPubkey.joins(:author_subscription).where("author_subscriptions.expires_at > ?", Time.current).find_by(nip05_name: params[:name])
    payload = {}

    if user_pubkey
      payload[:names] = user_pubkey.user.user_pubkeys.where.not(nip05_name: ["", nil]).map do |upk|
        [upk.nip05_name, upk.pubkey]
      end.to_h
    end

    render json: payload
  end

  def destroy
    @user_pubkey = current_user.user_pubkeys.find(params[:id])

    if @user_pubkey.destroy
      respond_to do |format|
        format.html { redirect_to edit_user_path, notice: "Successfully disconnected Nostr account" }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_user_path, alert: "Public key was not disconnected because of an error, please contact administrator" }
        format.turbo_stream do
          flash.now[:alert] = "Public key was not disconnected because of an error, please contact administrator"
        end
      end
    end
  end

  def update
    @user_pubkey = current_user.user_pubkeys.find(params[:id])

    if @user_pubkey.update(user_pubkey_params)
      head :ok
    else
      respond_to do |format|
        format.html { redirect_to edit_user_path, alert: "Public key was not update because of errors: #{@user_pubkey.errors.full_messages.join(", ")}" }
        format.turbo_stream do
          flash.now[:alert] = "Public key was not updated because of errors: #{@user_pubkey.errors.full_messages.join(", ")}"
        end
      end
    end
  end

  private

  def user_pubkey_params
    params.require(:user_pubkey).permit(:nip05_name)
  end
end
