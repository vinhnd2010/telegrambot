require 'httparty'
require 'json'
require 'open-uri'
require 'rack'
require 'digest/md5'
require 'base64'
require "dotenv/load"
require "pry"
require "date"
require "csv"
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
    top_assets = get_top_assets

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

  def all_orders
    symbols = collect_symbol
    today_orders = []
    symbols.each do |symbol|
      ["BTC", "ETH", "USDT"].each do |base|
        orders = @client.all_orders(symbol: "#{symbol}#{base}",
          startTime: (Time.now.getlocal("+07:00").to_date).to_time.to_i * 1000,
          endTime: Time.now.getlocal("+07:00").to_i * 1000)
        # binding.pry# if symbol == "BLZ" && base == "BTC"
        unless orders.empty?
          # unless orders["code"]
          #   binding.pry
          #   today_orders += orders.select do |order|
          #     order["updateTime"].to_i >= Time.now.getlocal("+07:00").to_date.to_time.to_i &&
          #     order["updateTime"].to_i <= Time.now.getlocal("+07:00").to_i
          #   end
          # end
        end
      end
    end
    binding.pry
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

  def collect_symbol
    asset_symbols = get_top_assets.keys
    symbols = asset_symbols

    objects = CSV.read("db/assets.csv")
    update_symbol_to_db asset_symbols

    objects.each do |row|
      symbols << row[0]
    end

    symbols
  end

  def update_symbol_to_db symbols
    CSV.open("db/assets.csv", "wb") do |csv|
      symbols.each do |symbol|
        csv << [symbol]
      end
    end
  end

  def get_top_assets
    top_assets = {}
    assets = @client.account_info["balances"]
    assets.each do |asset|
      asset_name = asset["asset"]
      asset_qty = asset["free"].to_f + asset["locked"].to_f
      if asset_qty > 0
        top_assets[asset_name] = asset_qty
      end
    end
    top_assets
  end
end

# BinanceApi.new(ENV["BNB_API_KEY"], ENV["BNB_SECRET_KEY"]).all_orders
