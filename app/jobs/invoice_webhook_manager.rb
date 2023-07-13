class InvoiceWebhookManager
  include Sidekiq::Worker
  sidekiq_options queue: "payment_webhooks"

  def perform(provider_name, webhook_data_json)
    webhook_data = JSON.parse(webhook_data)

    provider = Invoice::PROVIDERS[provider_name.to_sym]
    return Sentry.capture_message("[InvoiceWebhook][InvalidProvider] provider=#{provider_name} webhook=#{webhook_data_json}") unless provider

    return Sentry.capture_message("[InvoiceWebhook][InvalidSignature] provider=#{provider_name} webhook=#{webhook_data_json}") unless provider.valid?(webhook_data)

    external_id, order_id = provider.extract_ids_from_webhook(webhook_data)
    invoice = Invoice.find_by(external_id: external_id, order_id: order_id)
    return Sentry.capture_message("[InvoiceWebhook][NotFound] webhook=#{webhook_data_json} provider=#{provider_name}") if invoice.nil?

    Invoice.where(id: invoice.id).update_all("webhooks = webhooks || '#{webhook_data_json}'")

    # TODO: in theory underpayments could be handled by adjusting paid days
    # to actual amount but currently we don't support this
    # invoice.status.in?(%w[partially_paid created])
    return Sentry.capture_message("[InvoiceWebhook][InvalidStatus] provider=#{provider_name} status=#{invoice.status} invoice_id=#{invoice.id} webhook=#{webhook_data_json}") unless invoice.status === "created"

    return invoice.update(status: "expired") if provider.invoice_expired?(webhook_data)

    period_days = provider.count_paid_days_from(invoice, webhook_data).to_i

    if period_days === invoice.period_days.to_i
      subscription = AuthorSubscription.create_or_find_by(author_id: invoice.author_id)
      Invoice.transaction do
        result = AuthorSubscription.where(id: subscription.id).update_all("expires_at = COALESCE(expires_at, NOW()) + '#{period_days} days'")
        raise(ActiveRecord::Rollback, "Failed to update AuthorSubscription#expires_at") unless result === 1
        raise(ActiveRecord::Rollback, "Faield to change Invoice#status to 'paid") unless invoice.update(status: "paid", paid_at: Time.current)
      end
    else
      # TODO: there are payment providers having partial payments and refunds
      # in theory those could be supported with something like the following but for now we only handle full payments
      #
      # return if period_days === 0
      #
      # # TODO: it seems to be race-condition-free but and race conditions are
      # # extremely unlikely here but still makes sense to ensure
      # subscription = AuthorSubscription.create_or_find_by(author_id: invoice.author_id)
      # AuthorSubscription.where(id: subscription.id).update_all("expires_at = COALESCE(expires_at, NOW()) + '#{period_days} days'")
      # Invoice.where(id: invoice.id).update_all("status - 'paid', paid_days = COALESCE(paid_days, 0) + '#{period_days} days' ")
    end
  end
end
