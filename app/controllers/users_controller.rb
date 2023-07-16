class UsersController < ApplicationController
  skip_before_action :require_login, only: %i[create new]

  def create
    @user = User.new(user_params)

    if @user.save
      auto_login(@user)
      UserMailer.with(user: @user).confirm_sign_up_email.deliver_later
      redirect_back_or_to(:root, notice: "Login successful")
    else
      render action: "new", status: :unprocessable_entity
    end
  end

  def new
    @user = User.new
  end

  def update
    if current_user.update(user_params)
      redirect_to edit_user_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
