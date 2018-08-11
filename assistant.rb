require "pry"
require 'net/https'
require 'uri'
require 'json'
require "telegram/bot"
require "dotenv/load"

class Assistant
  def main
    token = ENV["TELE_SECRET_TOKEN"]

    Telegram::Bot::Client.run(token) do |bot|
      bot.listen do |message|
        chat_id = message.chat.id
        message_text = message.text
        mess = message_text.split()

        case mess[0]
        # /update issue_id, status_id
        when "/update"
          update_issue_status mess[1], mess[2]
          bot.api.send_message(chat_id: chat_id, text: "Already updated.")
        when "/hb_report"
          bot.api.send_message(chat_id: "@vinnotes", text: "Already updated.")
        when "/bnb_report"
          
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
