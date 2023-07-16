# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def confirm_sign_up_email
    @user = params[:user]
    @token = MemStore.add_email_confirmation(@user.email)

    mail(to: @user.email, subject: "Sign Up Success — Confirm Your Email")
  end
end
