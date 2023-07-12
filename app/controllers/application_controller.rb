class ApplicationController < ActionController::Base
  protected

  # TODO: Fix Turbo redirects
  # https://github.com/hotwired/turbo-rails/pull/367#issuecomment-1601733561
  # https://discuss.hotwired.dev/t/break-out-of-a-frame-during-form-redirect/1562/26
  # Since Rails 4 there was a joke:
  # - What should you do the first after bundle install Rails 4 ?
  # - What ?
  # - Remove Turbolinks!
  # It seems likes Turbo is "almost there" but not yet.
  def turbo_visit(url, frame: nil, action: nil)
    options = {frame: frame, action: action}.compact
    turbo_stream.append_all("head") do
      helpers.javascript_tag(<<~SCRIPT.strip, nonce: true, data: {turbo_cache: false})
        window.Turbo.visit("#{helpers.escape_javascript(url)}", #{options.to_json})
        document.currentScript.remove()
      SCRIPT
    end
  end
end
