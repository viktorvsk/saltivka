class UserPubkeysController < ApplicationController
  def create
    author = Author.create_or_find_by(pubkey: params[:pubkey])
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
  end
end
