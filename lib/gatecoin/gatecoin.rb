require 'rest-client'
require 'json'
require 'base64'
require 'byebug'

module Gatecoin
  class API
    attr_reader :key,
                :secret,
                :url

    def initialize(key:, secret:, url: 'https://api.gatecoin.com')
      @key = key
      @secret = secret
      @url = url
    end

    def balances
      get('/Balance/Balances')['balances']
    end

    def order(id)
      get("/Trade/Orders/#{id}")
    end

    def create_order(side:, size:, price:, pair:)
      side = case side
      when :buy then 'Bid'
      when :sell then 'Ask'
      else
        raise "Unknown side type #{side}. Use :buy or :sell as symbols."
      end

      opts = {
        Code: pair,
        Way: side,
        Amount: size.to_f.to_s,
        Price: price.to_f.to_s,
      }
      order = post('/Trade/Orders', opts)

      if !order['clOrderId']
        error = order['responseStatus']['message'] if order['responseStatus'] && order['responseStatus']['message']
        error ||= order
        raise Gatecoin::CreateOrderException.new(error)
      end

      order
    rescue => e
      raise Gatecoin::CreateOrderException.new(e.message)
    end

    def cancel_order(id)
      status = delete("/Trade/Orders/#{id}")

      if status['responseStatus'] && status['responseStatus']['errorCode']
        error = status['responseStatus']['message']
        error ||= status['responseStatus']
        raise Gatecoin::CancelOrderException.new(error)
      end

      status
    rescue => e
      raise Gatecoin::CancelOrderException.new(e.message)
    end

    def deposit_wallets
      addresses = get('/ElectronicWallet/DepositWallets')

      raise addresses['responseStatus']['message'] unless addresses['addresses']
      addresses['addresses']
    end

    def withdrawal(currency:, address:, amount:, comment: nil, validation: nil)
      opts = {
        AddressName: address,
        Amount: amount,
      }

      opts[:Comment] = comment if comment
      opts[:ValidationCode] = validation if validation

      status = post("/ElectronicWallet/withdrawals/#{currency}", opts)

      if status['responseStatus'] && status['responseStatus']['errorCode']
        error = status['responseStatus']['message']
        error ||= status['responseStatus']
        raise Gatecoin::WithdrawalException.new(error)
      end

      status
    end

    private

    def signature(timestamp, verb, content_type, path)
      content_type = '' if verb == 'GET'
      str = "#{verb}#{@url}#{path}#{content_type}#{timestamp}".downcase
      hmac = OpenSSL::HMAC.digest('sha256', @secret, str)
      a = Base64.encode64(hmac).to_s.gsub("\n",'')
    end

    def get(path, opts = {})
      uri = URI.parse("#{@url}#{path}")
      uri.query = URI.encode_www_form(opts[:params]) if opts[:params]

      response = RestClient.get(uri.to_s, auth_headers(uri.request_uri, 'GET'))

      if !opts[:skip_json]
        JSON.parse(response.body)
      else
        response.body
      end
    end

    def post(path, payload, opts = {})
      data = JSON.unparse(payload)
      response = RestClient.post("#{@url}#{path}", data, auth_headers(path, 'POST'))

      if !opts[:skip_json]
        JSON.parse(response.body)
      else
        response.body
      end
    end

    def delete(path, opts = {})
      response = RestClient.delete("#{@url}#{path}", auth_headers(path, 'DELETE'))

      if !opts[:skip_json]
        JSON.parse(response.body)
      else
        response.body
      end
    end

    def auth_headers(path, method)
      timestamp = Time.now.utc.to_f.round(3).to_s
      content_type = 'application/json'
      sign = signature(timestamp, method, content_type, path)

      {
        'Content-Type' => content_type,
        'API_PUBLIC_KEY' => @key,
        'API_REQUEST_DATE' => "#{timestamp}",
        'API_REQUEST_SIGNATURE' => sign,
      }
    end
  end
end
