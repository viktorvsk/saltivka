class InvoicesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[update]

  def new
    @invoice = Invoice.new(amount_sats: RELAY_CONFIG.default_invoice_amount, period_days: RELAY_CONFIG.default_invoice_period)
  end

  def show
  end

  def create
    provider = Invoice::PROVIDERS[invoice_params[:provider].to_sym]

    unless provider
      author = Author.create_or_find_by(pubkey: invoice_params[:pubkey])
      @invoice = author.invoices.new(author: author, pubkey: invoice_params[:pubkey], period_days: invoice_params[:period_days])
      @invoice.errors.add(:provider, "is unknown")
      return invalid!
    end

    @invoice = provider.create_internal_invoice(invoice_params[:period_days], invoice_params[:pubkey])
    return invalid! unless @invoice.persisted?

    response = provider.create_external_invoice(@invoice.request)
    response_body = begin
      JSON.parse(response.read_body)
    rescue => e
      Sentry.capture_exception(e)
      return fail!
    end

    unless provider.successul_response?(response.code, response_body)
      Sentry.capture_message("[FailedInvoice] provider=#{provider} response=#{response_body.to_json} http_code=#{response.code}")
      return fail!
    end

    external_id = provider.external_id_from_response(response_body)

    unless @invoice.update(response: response_body, external_id: external_id, status: "created")
      Sentry.capture_message("[FailedInvoice] provider=#{provider} external_id=#{external_id} response=#{response_body.to_json} http_code=#{response.code}")
      return fail!
    end

    if @invoice.update(response: response)
      hosted_checkout_url = provider.hosted_checkout_url_from(response_body)
      render turbo_stream: turbo_visit(hosted_checkout_url)
    else
      invalid!
    end
  end

  def update
    webhook_data = params.except(:action, :controller, :provider, :invoice)

    InvoiceWebhookManager.perform_async(params[:provider], webhook_data.to_json)

    head :ok
  end

  private

  def invoice_params
    params.require(:invoice).permit(:pubkey, :provider, :period_days)
  end

  def invalid!
    render :new, status: :unprocessable_entity
  end

  def fail!
    flash.now[:notice] = "Oops something went wrong, we are already investigating it"
    @invoice.update!(status: "failed")
    render :new, status: :unprocessable_entity
  end
end
