class Admin::AuthorSubscriptionsController < AdminController
  def index
    @pagy, @author_subscriptions = pagy(AuthorSubscription.order(created_at: :desc).all)
  end

  def show
    @author_subscription = AuthorSubscription.find(params[:id])
  end

  def create
    pubkey = author_subscription_params[:pubkey]
    author = begin
      Author.select(:id, :pubkey).where("LOWER(authors.pubkey) = ?", pubkey).first_or_create(pubkey: pubkey)
    rescue ActiveRecord::RecordNotUnique
      Author.select(:id, :pubkey).where("LOWER(authors.pubkey) = ?", pubkey).first
    end
    @author_subscription = AuthorSubscription.create_or_find_by!(author_id: author.id)
    AuthorSubscription.where(id: @author_subscription.id).update_all("expires_at = COALESCE(expires_at, NOW()) + '#{author_subscription_params[:period_days]} days'")

    render turbo_stream: turbo_visit(admin_author_subscriptions_path)
  end

  def destroy
    AuthorSubscription.find(params[:id]).destroy

    redirect_to admin_author_subscriptions_path
  end

  private

  def author_subscription_params
    params.require(:author_subscription).permit(:pubkey, :period_days)
  end
end
