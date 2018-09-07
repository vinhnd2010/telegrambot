require "pry"
require 'net/https'
require 'uri'
require 'json'
require "telegram/bot"
require "dotenv/load"
require_relative "huobi_pro"

class Assistant
  def main
    token = ENV["TELE_SECRET_TOKEN"]
    hb_report = "Huobi report"
    bnb_report = "Binance report"
    order_24h = "Huobi 24h Order"
    date_time_format = "%Y-%m-%d %H:%M:%S"
    keyboard_arr = [[hb_report, bnb_report], ["/hb_report", "/hb_24h_orders"]]

    Telegram::Bot::Client.run(token) do |bot|
      bot.listen do |message|
        chat_id = message.chat.id
        message_text = message.text
        mess = message_text.split()
        first_name = message.chat.first_name

        hb_access_key = ENV["HB_ACCESS_KEY_#{chat_id}"]
        hb_secret_key = ENV["HB_SECRET_KEY_#{chat_id}"]
        # hb_account_id = ENV["HB_ACCOUNT_ID_#{chat_id}"]
        if hb_access_key && hb_secret_key
          hb_account_id = HuobiPro.new(hb_access_key, hb_secret_key).accounts["data"][0]["id"]
          huobi_pro = HuobiPro.new(hb_access_key, hb_secret_key, hb_account_id)
        end

        case mess[0]
        when "/start"
          res_message = "Hello #{first_name}! \n Please choose the following actions:"
          bot.api.send_message(chat_id: chat_id, text: res_message,
            reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: keyboard_arr, one_time_keyboard: true))
        # /update issue_id, status_id
        when "/update"
          update_issue_status mess[1], mess[2]
          bot.api.send_message(chat_id: chat_id, text: "Already updated.")
        when hb_report.split()[0], "/hb_report"
          res_message = ""
          if huobi_pro
            top_tokens, total_usdt = huobi_pro.balance_in_usdt
            top_tokens.each do |token|
              res_message += "\n#{token[0].upcase}:    #{token[1].round(4)}"
            end
            res_message += "\n====================\n Your balances: #{total_usdt.round 0} USDT"
          else
            res_message = "Need permission. Please contact administrator. Thank you!"
          end
          bot.api.send_message(chat_id: chat_id, text: res_message)
        when bnb_report.split()[0]
          bot.api.send_message(chat_id: chat_id, text: "Developing ...")
        when order_24h.split()[0], "/hb_24h_orders"
          res_message = ""
          today = Time.now.getlocal("+07:00").to_date
          one_month_orders = huobi_pro.orders["data"]

          orders_24h = one_month_orders.select do |order|
            filled_at = Time.at(order['finished-at']/1000).getlocal('+07:00').to_date.to_s
            filled_at >= (today - 1).to_s && filled_at <= today.to_s
          end
          res_message += "Total: #{orders_24h.size}\n--------------------------------"

          orders_24h.each_with_index do |order, index|
            res_message += "\n===========================" if index > 0
            res_message += "\n#{order['symbol'].upcase} | #{order['type'].split('-').first.upcase}"
            res_message += "\nAmount: #{order['amount'].to_f.round(9)} \nPrice:       #{order['price'].to_f.round(9)}"
            res_message += "\nFilled_at: #{Time.at(order['finished-at']/1000).getlocal('+07:00').strftime(date_time_format)}"
          end
          bot.api.send_message(chat_id: chat_id, text: res_message)
        else
          bot.api.send_message(chat_id: chat_id, text: "Please choose the following actions:",
            reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: keyboard_arr, one_time_keyboard: true))
        end
      end
    end
  end

  private
  def update_issue_status issue_id, new_status_id, change_note=""
    base_url = "https://redmine.knstats.com/" 
    api_token = ENV["REDMINE_API_TOKEN"]

    payload = {
      issue: {
        notes: change_note,
        status_id: new_status_id
      }
    }

    url = "#{base_url}/issues/#{issue_id}.json" 
    uri = URI.parse(url)
    req = Net::HTTP::Put.new(uri.request_uri)

    req["Content-Type"] = "application/json" 
    req['X-Redmine-API-Key'] = api_token
    req.body = payload.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(req)
    return response
  end
end

Assistant.new.main()
