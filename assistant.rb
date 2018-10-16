require "pry"
require 'net/https'
require 'uri'
require 'json'
require "telegram/bot"
require "dotenv/load"
require 'active_support'
require 'active_support/core_ext'
require_relative "huobi_pro"
require_relative "binance_api"

class Assistant
  def main
    tele_secret_token = ENV["TELE_SECRET_TOKEN"]
    hb_balances = "/hb_balances"
    bnb_balances = "/bnb_balances"
    keyboard_arr = [
      [hb_balances, bnb_balances],
      ["/hb_24h_orders", "/bnb_24h_orders"],
      ["/hb_today_orders", "/bnb_today_orders"]
    ]

    Telegram::Bot::Client.run(tele_secret_token) do |bot|
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

        if ENV["BNB_API_KEY"] && ENV["BNB_SECRET_KEY"]
          binance_api = BinanceApi.new(ENV["BNB_API_KEY"], ENV["BNB_SECRET_KEY"])
        end

        case mess[0]
        when "/start"
          res_message = "Hello #{first_name}! \n Please choose the following actions:"
          bot.api.send_message(chat_id: chat_id, text: res_message,
            reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: keyboard_arr, one_time_keyboard: true))
        when hb_balances
          res_message = ""
          if huobi_pro
            top_tokens, total_usdt = huobi_pro.balance_in_usdt
            top_tokens.each do |token|
              res_message += "\n#{token[0].upcase}:    #{token[1].round(4)}"
            end
            res_message += "\n==========================\n Your HB balances: #{total_usdt.round 0} USDT"
          else
            res_message = "Need permission. Please contact administrator. Thank you!"
          end
          bot.api.send_message(chat_id: chat_id, text: res_message)
        when bnb_balances
           res_message = ""
          if binance_api
            top_tokens, total_usdt = binance_api.balance_in_usdt
            top_tokens.each do |token|
              res_message += "\n#{token[0].upcase}:    #{token[1].round(4)}"
            end
            res_message += "\n==============================\n Your Binance balances: #{total_usdt.round 0} USDT"
          else
            res_message = "Need permission. Please contact administrator. Thank you!"
          end
          bot.api.send_message(chat_id: chat_id, text: res_message)
        when "/hb_24h_orders"
          res_message = fetch_orders(huobi_pro, 1)
          bot.api.send_message(chat_id: chat_id, text: res_message)
        when "/hb_today_orders"
          res_message = fetch_orders(huobi_pro, 0)
          bot.api.send_message(chat_id: chat_id, text: res_message)
        else
          bot.api.send_message(chat_id: chat_id, text: "Please choose the following actions:",
            reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: keyboard_arr, one_time_keyboard: true))
        end
      end
    end
  end

  private
  def fetch_orders huobi_pro, dates=nil
    res_message = ""
    date_time_format = "%Y-%m-%d %H:%M:%S"
    today = Time.now.getlocal("+07:00").to_date
    six_months_orders = huobi_pro.orders["data"]

    orders_in_dates = six_months_orders.select do |order|
      filled_at = Time.at(order['finished-at']/1000).getlocal('+07:00').to_date.to_s
      filled_at >= (today - dates.to_i).to_s && filled_at <= today.to_s
    end
    res_message += "Total: #{orders_in_dates.size}\n--------------------------------"

    orders_in_dates.each_with_index do |order, index|
      res_message += "\n===========================" if index > 0
      res_message += "\n#{order['symbol'].upcase} | #{order['type'].split('-').first.upcase}"
      res_message += "\nAmount: #{order['amount'].to_f.round(9)} \nPrice:       #{order['price'].to_f.round(9)}"
      res_message += "\nFilled_at: #{Time.at(order['finished-at']/1000).getlocal('+07:00').strftime(date_time_format)}"
    end
    res_message
  end
end

Assistant.new.main()
