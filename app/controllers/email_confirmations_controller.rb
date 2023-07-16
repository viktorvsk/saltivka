class EmailConfirmationsController < ApplicationController
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
end
