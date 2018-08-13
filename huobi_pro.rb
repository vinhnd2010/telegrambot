require 'httparty'
require 'json'
require 'open-uri'
require 'rack'
require 'digest/md5'
require 'base64'
require "dotenv/load"
require "pry"

class HuobiPro
  def initialize(access_key,secret_key,account_id,signature_version="2")
      @access_key = access_key
      @secret_key = secret_key
      @signature_version = signature_version
      @account_id = account_id
      @uri = URI.parse "https://api.huobi.pro/"
      @header = {
        'Content-Type'=> 'application/json',
        'Accept' => 'application/json',
        'Accept-Language' => 'en',
        'User-Agent'=> 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36'
      }
  end

  def symbols
    path = "/v1/common/symbols"
    request_method = "GET"
    params ={}
    util(path,params,request_method)
  end

  def depth(symbol,type="step0")
    path = "/market/depth"
    request_method = "GET"
    params ={"symbol" => symbol,"type"=>type}
    util(path,params,request_method)
  end

  def history_kline(symbol,period,size=150)
    path = "/market/history/kline"
    request_method = "GET"
    params ={"symbol" => symbol,"period"=>period,"size" => size}
    util(path,params,request_method)
  end

  def merged(symbol)
    path = "/market/detail/merged"
    request_method = "GET"
    params ={"symbol" => symbol}
    util(path,params,request_method)
  end

  def market_trade(symbol)
    path = "/market/depth"
    request_method = "GET"
    params ={"symbol" => symbol}
    util(path,params,request_method)
  end

  def trade_detail(symbol)
    path = "/market/trade"
    request_method = "GET"
    params ={"symbol" => symbol}
    util(path,params,request_method)
  end

  def history_trade(symbol,size=1)
    path = "/market/history/trade"
    request_method = "GET"
    params ={"symbol" => symbol,"size" => size}
    util(path,params,request_method)
  end

  ## 获取 Market Detail 24小时成交量数据
  def market_detail(symbol)
    path = "/market/detail"
    request_method = "GET"
    params ={"symbol" => symbol}
    util(path,params,request_method)
  end

  def currencys
    path = "/v1/common/currencys"
    request_method = "GET"
    params ={}
    util(path,params,request_method)
  end

  def accounts
    path = "/v1/account/accounts"
    request_method = "GET"
    params ={}
    json = util(path,params,request_method)
  end

  def balances
    path = "/v1/account/accounts/#{@account_id}/balance"
    request_method = "GET"
    balances = {"account_id"=>@account_id}
    util(path,{},request_method)
  end

  ## 创建并执行一个新订单
  ## 如果使用借贷资产交易
  ## 请在下单接口/v1/order/orders/place
  ## 请求参数source中填写'margin-api'
  def new_order(symbol,side,price,count)
    params ={
      "account-id" => @account_id,
      "amount" => count,
      "price" => price,
      "source" => "api",
      "symbol" => symbol,
      "type" => "#{side}-limit"
    }
    path = "/v1/order/orders/place"
    request_method = "POST"
    util(path,params,request_method)
  end

  def order_status(order_id,market)
    path = "/v1/order/orders/#{order_id}"
    request_method = "GET"
    params ={"order-id" => order_id}
    util(path,params,request_method)
  end

  def matchresults(order_id)
    path = "/v1/order/orders/#{order_id}/matchresults"
    request_method = "GET"
    params ={"order-id" => order_id}
    util(path,params,request_method)
  end

  def open_orders(symbol,side)
    params ={
      "symbol" => symbol,
      "types" => "#{side}-limit",
      "states" => "pre-submitted,submitted,partial-filled,partial-canceled"
    }
    path = "/v1/order/openOrders"
    request_method = "GET"
    util(path,params,request_method)
  end

  def history_matchresults(symbol)
    path = "/v1/order/matchresults"
    params ={"symbol"=>symbol}
    request_method = "GET"
    util(path,params,request_method)
  end

  def balance_in_usdt
    usdt_amount = 0
    top_tokens = {}
    balances = self.balances
    tokens = balances["data"]["list"]
    large_tokens = tokens.each do |token| 
      if (balance = token['balance'].to_f) > 0
        top_tokens[token['currency']] = top_tokens[token['currency']].to_f + token['balance'].to_f
      end
    end
      top_tokens.keys.each do |token_name|
        balance = top_tokens[token_name]
        if token_name == "usdt"
          usdt_amount += balance
        else
          if trade_detail("#{token_name}usdt")["status"] == "ok"
            usdt_amount += balance * trade_detail("#{token_name}usdt")["tick"]["data"].first["price"]
          else
            usdt_amount += balance * trade_detail("#{token_name}btc")["tick"]["data"].first["price"] *
              trade_detail("btcusdt")["tick"]["data"].first["price"]
          end
        end
      end
    [top_tokens, usdt_amount]
  end
  
  private
  def util(path,params,request_method)
    h =  {
      "AccessKeyId"=>@access_key,
      "SignatureMethod"=>"HmacSHA256",
      "SignatureVersion"=>@signature_version,
      "Timestamp"=> Time.now.getutc.strftime("%Y-%m-%dT%H:%M:%S")
    }
    h = h.merge(params) if request_method == "GET"
    data = "#{request_method}\napi.huobi.pro\n#{path}\n#{Rack::Utils.build_query(hash_sort(h))}"
    h["Signature"] = sign(data)
    url = "https://api.huobi.pro#{path}?#{Rack::Utils.build_query(h)}"
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.use_ssl = true
    begin
      JSON.parse http.send_request(request_method, url, JSON.dump(params),@header).body
    rescue Exception => e
      {"message" => 'error' ,"request_error" => e.message}
    end
  end

  def sign(data)
    Base64.encode64(OpenSSL::HMAC.digest('sha256',@secret_key,data)).gsub("\n","")
  end

  def hash_sort(ha)
    Hash[ha.sort_by{|key, val|key}]
  end
end

