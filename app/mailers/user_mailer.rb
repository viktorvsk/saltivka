# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def confirm_sign_up_email
    @user = params[:user]
    @token = MemStore.add_email_confirmation(@user.email)

    mail(to: @user.email, subject: "Sign Up Success — Confirm Your Email")
  end

  def reset_password_email(user)
    @user = User.find(user.id)
    @url = edit_password_reset_url(@user.reset_password_token)
    mail(to: user.email,
      subject: "Your password has been reset")
  end
end
