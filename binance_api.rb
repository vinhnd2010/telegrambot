require 'httparty'
require 'json'
require 'open-uri'
require 'rack'
require 'digest/md5'
require 'base64'
require "dotenv/load"
require "pry"
require "date"
require "net/http"
require "binance"

class BinanceApi
  def initialize access_key, secret_key
    @uri = URI.parse "https://api.binance.com"
    @header = {
        'Content-Type'=> 'application/json',
        'Accept' => 'application/json',
        'Accept-Language' => 'en'
      }
    @client = Binance::Client::REST.new api_key: access_key, secret_key: secret_key
  end

  def day_changes symbol
    path = "/api/v1/ticker/24hr"
    params = {"symbol" => symbol}

    body = util_get path, params
    p body
  end

  def recent_trades symbol
    path = "/api/v1/trades"
    params = {"symbol" => symbol, limit: 5}

    body = util_get path, params
    p body
  end

  def balance_in_usdt
    usdt_amount = 0
    top_assets = {}
    assets = @client.account_info["balances"]
    assets.each do |asset|
      asset_name = asset["asset"]
      asset_qty = asset["free"].to_f + asset["locked"].to_f
      if asset_qty > 0
        top_assets[asset_name] = asset_qty
      end
    end

    top_assets.each do |asset|
      balance = asset[1]
      asset_name = asset[0]

      if asset[0] == "USDT"
        usdt_amount += balance
      else
        if (price = @client.price(symbol: "#{asset_name}USDT")["price"]).present?
          usdt_amount += balance * price.to_f
        else
          usdt_amount += balance * @client.price(symbol: "#{asset_name}BTC")["price"].to_f *
            @client.price(symbol: "BTCUSDT")["price"].to_f
        end
      end
    end
    [top_assets, usdt_amount]
  end

  private
  def util_get path, params
    url = "#{@uri}#{path}?#{Rack::Utils.build_query(params)}"
    http = Net::HTTP.new @uri.host, @uri.port
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    request = Net::HTTP::Get.new url, @header
    begin
      JSON.parse http.request(request).body
    rescue Exception => e
      {"message" => "error", "request_error" => e.message}
    end
  end
end

# Binance.new.day_changes("CMTBTC")
# BinanceApi.new(ENV["BNB_API_KEY"], ENV["BNB_SECRET_KEY"]).balances
