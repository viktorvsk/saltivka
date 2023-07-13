class Admin::AuthorSubscriptionsController < AdminController
  def index
    @author_subscriptions = AuthorSubscription.order(created_at: :desc).all
  end

  def show
    @author_subscription = AuthorSubscription.find(params[:id])
  end

  def create
    author = Author.create_or_find_by(pubkey: author_subscription_params[:pubkey])
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
