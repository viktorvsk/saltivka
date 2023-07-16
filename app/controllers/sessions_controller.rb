class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[create new]

  def create
    @user = login(params[:user][:email], params[:user][:password])

    if @user
      redirect_back_or_to(:root, notice: "Login successful")
    else
      flash.now[:alert] = "Login failed"
      render action: "new"
    end
  end

  def destroy
    logout
    redirect_to(:root, notice: "Logged out!")
  end
end
