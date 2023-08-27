class OpenNode < BaseProvider
  def create_charge_url
    @create_charge_url ||= URI("https://api.opennode.com/v1/charges")
  end

  def short_name
    "opennode"
  end

  def build_request(amount:, description:, order_id:)
    base_url = URI.parse(RELAY_CONFIG.self_url)
    base_url.scheme = (base_url.scheme == "ws") ? "http" : "https"

    {
      amount: amount,
      description: description,
      order_id: order_id,
      callback_url: "#{base_url}/payment-callback/#{short_name}",
      success_url: "#{base_url}/payment-successful",
      ttl: RELAY_CONFIG.invoice_ttl
    }
  end

  def valid?(webhook)
    webhook["hashed_order"] == OpenSSL::HMAC.hexdigest("sha256", api_key, webhook["id"])
  end

  def hosted_checkout_url_from(response_body)
    response_body["data"]["hosted_checkout_url"]
  end

  def successul_response?(code, response_body)
    code === "200" && response_body["data"].present? && response_body["data"]["hosted_checkout_url"].present?
  end

  def request_headers
    {
      accept: "application/json",
      "Content-Type": "application/json",
      Authorization: api_key
    }
  end

  def external_id_from_response(response_body)
    response_body["data"]["id"]
  end

  def invoice_expired?(webhook)
    webhook["status"] === "expired"
  end

  def extract_ids_from_webhook(webhook_data)
    [
      webhook_data["id"],
      webhook_data["order_id"]
    ]
  end

  def count_paid_days_from(invoice, webhook)
    case webhook["status"]
    when "paid"
      # TODO: we could potentially add more days according to overpaid amount
      # but its not really clear how refunding works
      # invoice.period_days + (webhook["overpaid_by"].to_i / RELAY_CONFIG.price_per_day.to_i)

      # TODO: document edge-case where this config was changed after invoice created and before it is paid
      invoice.period_days
    when "underpaid"
      # TODO: we could potentially add days even for underpaid transactions
      # but its not really clear how refunding transactions look like
      #
      # invoice.period_days - (webhook["missing_amt"].to_i / RELAY_CONFIG.price_per_day.to_i) - 1
      Sentry.capture_message("[#{short_name}][underpaid] invoice_id=#{invoice.id} webhook=#{webhook.to_json}")
      0
    when "refunded"
      # TODO: in theory days could be substructed on refund but its not clear
      # how it works on Open Node side and how to handle edge-cases if it was refunded
      # after actually  days were already "used"
      Sentry.capture_message("[#{short_name}][refunded] invoice_id=#{invoice.id} webhook=#{webhook.to_json}")
      0
    else
      Sentry.capture_message("[#{short_name}][#{webhook["status"]}] invoice_id=#{invoice.id} webhook=#{webhook.to_json}")
      0
    end
  end
end
