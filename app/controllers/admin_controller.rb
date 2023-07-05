class AdminController < ApplicationController
  before_action :require_login, :require_admin

  layout "admin"

  protected

  def not_authenticated
    redirect_to new_session_path
  end

  def require_admin
    not_authenticated unless current_user.try(:admin?)
  end
end
