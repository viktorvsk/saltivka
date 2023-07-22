class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[create new]

  def create
    @user = login(params[:user][:email], params[:user][:password])

    if @user
      redirect_back_or_to(:root, notice: "Login successful")
    else
      flash.now[:alert] = "Login failed"
      respond_to do |format|
        format.html do
          render action: "new"
        end
        format.turbo_stream
      end
    end
  end

  def destroy
    logout
    redirect_to(:root, notice: "Logged out!")
  end
end
