class PasswordResetsController < ApplicationController
  skip_before_action :require_login

  def create
    @user = User.find_by_email(params[:email])

    @user&.deliver_reset_password_instructions!

    redirect_to(root_path, notice: "Instructions have been sent to your email.")
  end

  def edit
    @user = User.load_from_reset_password_token(params[:id])
    @token = params[:id]
    unless @user
      flash[:alert] = "Reset password code expired or invalid"
      not_authenticated
    end
  end

  def update
    @token = params[:user][:token]
    @user = User.load_from_reset_password_token(@token)

    if @user.blank?
      flash[:alert] = "Reset password code expired or invalid"
      not_authenticated
    end

    @user.password_confirmation = params[:user][:password_confirmation]

    if @user.change_password!(params[:user][:password])
      auto_login(@user)
      redirect_to(root_path, notice: "Password was successfu lly updated.")
    else
      render action: "edit"
    end
  end
end
