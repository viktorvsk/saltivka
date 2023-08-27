class BaseProvider
  attr_reader :api_key

  def initialize(api_key)
    @api_key = api_key
  end

  def create_internal_invoice(period, pubkey)
    amount = period.to_i * RELAY_CONFIG.price_per_day.to_i
    order_id = SecureRandom.urlsafe_base64(32)
    description = "Paying #{amount} sats for #{period} days of using #{RELAY_CONFIG.relay_name} relay"
    request = build_request(amount: amount, order_id: order_id, description: description)
    invoice_params = {
      amount_sats: amount,
      period_days: period,
      request: request,
      provider: short_name,
      order_id: order_id
    }

    Author.from_pubkey(pubkey).invoices.create(invoice_params)
  end

  def create_external_invoice(payload)
    http = Net::HTTP.new(create_charge_url.host, create_charge_url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(create_charge_url)

    request_headers.each do |hname, hvalue|
      request[hname] = hvalue
    end
    request.body = payload.to_json

    http.request(request)
  end

  def valid?(webhook)
    raise NotImplementedError
  end

  def hosted_checkout_url_from(response)
    raise NotImplementedError
  end

  def successul_response?(response)
    raise NotImplementedError
  end

  def build_request(amount:, description:, order_id:)
    raise NotImplementedError
  end

  def short_name
    raise NotImplementedError
  end

  def request_headers
    raise NotImplementedError
  end

  def external_id_from_response(response_body)
    raise NotImplementedError
  end

  def invoice_expired?(webhook)
    raise NotImplementedError
  end

  def extract_ids_from_webhook(webhook)
    raise NotImplementedError
  end

  # In theory we can support negative days count to subsctruct from active
  # subscriptions but currently its not implemented for any provider
  # and its not 100% clear how to handle edge-cases like:
  # "what if refund happened after actual days had been used already?"
  def count_paid_days_from(webhook)
    raise NotImplementedError
  end
end
