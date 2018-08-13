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

    Telegram::Bot::Client.run(token) do |bot|
      bot.listen do |message|
        chat_id = message.chat.id
        message_text = message.text
        mess = message_text.split()
        first_name = message.chat.first_name

        hb_access_key = ENV["HB_ACCESS_KEY_#{chat_id}"]
        hb_secret_key = ENV["HB_SECRET_KEY_#{chat_id}"]
        hb_account_id = ENV["HB_ACCOUNT_ID_#{chat_id}"]
        if hb_access_key && hb_secret_key && hb_account_id
          huobi_pro = HuobiPro.new(hb_access_key, hb_secret_key, hb_account_id)
        end

        case mess[0]
        when "/start"
          hour = Time.now.hour
          res_message = if hour < 12
            "Good morning #{first_name}!"
          elsif 12 <= hour && hour <= 18
            "Good afternoon #{first_name}!"
          else
            "Hello #{first_name}!"
          end
          bot.api.send_message(chat_id: chat_id, text: res_message)
        # /update issue_id, status_id
        when "/update"
          update_issue_status mess[1], mess[2]
          bot.api.send_message(chat_id: chat_id, text: "Already updated.")
        when "/hb_report"
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
        when "/bnb_report"
          bot.api.send_message(chat_id: chat_id, text: "Developing ...")
        else
          bot.api.send_message(chat_id: chat_id, text: "Thanks!")
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
