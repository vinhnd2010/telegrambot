require 'telegram/bot'
require 'daybreak'
require 'pry'
require 'dotenv/load'

class Kyberbot
  def main
    token = ENV["SECRET_TOKEN"]

    Telegram::Bot::Client.run(token) do |bot|
      bot.listen do |message|
        db = Daybreak::DB.new "kybergame.db"
        db[:tests] ||= []
        db[:correct_users] ||= []
        today = Time.now.strftime("%d/%m/%Y")
        chat_id = message.chat.id
        message_text = message.text

        case
        when message_text == '/start'
          bot.api.send_message(chat_id: chat_id, text: "Welcome to KyberNetwork!")
        when message_text == '/test'
          if check_number_test(db, message.chat.id, today)
            mark = 0
            db[:questions].shuffle.each do |question|
              question_text = question[:question]
              answers  = Telegram::Bot::Types::ReplyKeyboardMarkup
                .new(keyboard: [question[:answer1], question[:answer2]], one_time_keyboard: true)

              bot.api.send_message(chat_id: chat_id, text: question_text, reply_markup: answers)

              bot.listen do |answer|
                if answer.text == question[:ra]
                  mark += 1
                end
                break
              end
            end
            write_data db, message, chat_id, mark, today
            bot.api.send_message(chat_id: message.chat.id, text: "Your marks: #{mark}")
          else
            bot.api.send_message(chat_id: message.chat.id, text: "Ban da tra loi 1 lan roi, hay doi den ngay mai.")
          end
        when message_text.include?('/result')
          password = message_text.split.last
          if password == ENV["TELEBOTPW"]
            correct_users = db[:correct_users].detect do |correct_users_by_day|
               correct_users_by_day[today]
            end
            text = if correct_users
              correct_users[today].shuffle[0..2].join(", ")
            else
              "Khong co ai tra loi dung."
            end
          else
            text = "Sai mat khau"
          end
          bot.api.send_message(chat_id: message.chat.id, text: text)
        end
        db.close
      end
    end
  end

  private
  def check_number_test db, chat_id, today
    db[:tests].each do |test|
      if user_tests = test[today]
        return false if user_tests.detect do |user_test|
          user_test[chat_id]
        end
      end
    end
    return true
  end

  def write_data db, message, chat_id, mark, today
    # write all of tests
    today_tests = db[:tests].detect do |test_by_date|
      test_by_date[today]
    end
    if today_tests
      today_tests << {chat_id => mark}
    else
      db[:tests] << {today => [{chat_id => mark}]}
    end
    db.set! :tests, db[:tests]

    #write users who answer correct all of questions
    if mark == 3
      correct_users = db[:correct_users].detect do |correct_by_date|
        correct_by_date[today]
      end
      if correct_users
        correct_users[today] << "@#{message.chat.username}"
      else
        db[:correct_users] << {today => ["@#{message.chat.username}"]}
      end
      db.set! :correct_users, db[:correct_users]
    end
  end
end

Kyberbot.new.main();
