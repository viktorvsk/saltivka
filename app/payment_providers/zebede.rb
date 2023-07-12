class Zebede < BaseProvider
  def create_charge_url
    @create_charge_url ||= URI("https://api.zebedee.io/v0/charges")
  end

  def short_name
    "zebede"
  end

  def build_request(amount:, description:, order_id:)
    base_url = URI.parse(RELAY_CONFIG.self_url)
    base_url.scheme = (base_url.scheme == "ws") ? "http" : "https"

    {
      amount: amount.to_i * 1000, # zbd expect msats
      description: description,
      internalId: order_id,
      callbackUrl: "#{base_url}/payment-callback/#{short_name}",
      success_url: "#{base_url}/payment-successful",
      expiresIn: RELAY_CONFIG.invoice_ttl * 60
    }
  end

  # TODO: Zebede doesn't have hosted checkout, need to create our own page
  def hosted_checkout_url_from(response_body)
    raise NotImplementedError
  end

  def successul_response?(code, response_body)
    response_body["message"] === "Successfully created Charge." && response_body["success"] == true && response_body["data"].present?
  end

  def request_headers
    {
      "Content-Type": "application/json",
      apikey: api_key
    }
  end

  def external_id_from_response(response_body)
    response_body["data"]["id"]
  end

  # TODO: its not clear out of documentation how expired status looks like
  def invoice_expired?(webhook)
    raise NotImplementedError
  end

  # TODO: there is no webhook documentation currently
  def extract_ids_from_webhook(webhook_data)
    raise NotImplementedError
  end

  # TODO: there is no webhook documentation currently
  def count_paid_days_from(invoice, webhook)
    raise NotImplementedError
  end

  # TODO: docs are not ready https://docs.zebedee.io/docs/webhook-events/
  # Webhooks section is TBD
  def valid?(webhook)
    raise NotImplementedError
  end
end
