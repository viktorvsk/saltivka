class ApplicationMailer < ActionMailer::Base
  default from: RELAY_CONFIG.mailer_default_from
  layout "mailer"
end
