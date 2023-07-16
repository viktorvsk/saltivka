class EmailConfirmationsController < ApplicationController
  skip_before_action :require_login, only: %i[show]

  def show
    token = params[:id]
    email = MemStore.find_email_to_confirm(token)

    if email && (User.where(email: email, confirmed_at: nil).update_all(confirmed_at: Time.current) == 1)
      MemStore.confirm_email(token)
      user = User.find_by_email(email)
      auto_login(user)
      flash[:notice] = "Email was successfully confirmed!"
    else
      flash[:alert] = "Email was not confirmed: confirmation token not found or expired"
    end

    redirect_to root_path
  end

  def create
    UserMailer.with(user: current_user).confirm_sign_up_email.deliver_later
    redirect_to edit_user_path, notice: "Successfully sent confirmation email, please, check your inbox!"
  end
end
