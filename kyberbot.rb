require "telegram/bot"
require "daybreak"
require "pry"
require "dotenv/load"
require "date"
require "sinatra"

class Kyberbot
  def main
    token = ENV["SECRET_TOKEN"]

    Telegram::Bot::Client.run(token) do |bot|
      db = Daybreak::DB.new "kybergame.db"
      question_ids = db[:questions].keys

      bot.listen do |message|
        today = Time.now.strftime("%d/%m/%Y")
        yesterday = (Date.today - 1).strftime("%d/%m/%Y")
        db.load
        db[:tests] ||= {}
        db[:tests][today] ||= {}
        db[:correct_users] ||= {}
        db[:correct_users][today] ||= []
        db[:winners] ||= {}
        db[:winners][today] ||= []
        chat_id = message.chat.id
        message_text = message.text

        case
        when message_text == '/start'
          bot.api.send_message(chat_id: chat_id, text: "Welcome to KyberNetwork!",
            reply_markup: Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: ["/test"], one_time_keyboard: true))
        when message_text == '/test'
          start_testing bot, db, chat_id, today
        when message_text.split[0] == '/result'
          get_result bot, db, message_text, chat_id, yesterday
        else
          handle_user_test bot, db, message, chat_id, question_ids, today
        end
      end
      db.close
    end
  end

  private
  def check_number_test db, chat_id, date
    db[:tests][date][chat_id].nil? || db[:tests][date][chat_id][:status] != "tested"
  end

  def start_testing bot, db, chat_id, today
    if check_number_test(db, chat_id, today)
      db[:tests][today].merge!({chat_id => {:status => 'testing', :question_ids => [], :mark => 0}})
      db.set! :tests, db[:tests]
      send_question bot, db, chat_id, today
    else
      bot.api.send_message(chat_id: chat_id, text: "Ban da tra loi 1 lan roi, hay doi den ngay mai.")
    end
  end

  def send_question bot, db, chat_id, date
    question_ids = db[:questions].keys
    question_id = (question_ids - db[:tests][date][chat_id][:question_ids]).sample

    question = db[:questions][question_id]
    question_text = question[:question]
    answers = Telegram::Bot::Types::ReplyKeyboardMarkup
      .new(keyboard: [question[:answer1], question[:answer2]], one_time_keyboard: true)

    bot.api.send_message(chat_id: chat_id, text: question_text, reply_markup: answers)

    # update question_ids of user test
    db[:tests][date][chat_id][:question_ids] << question_id
    db.set! :tests, db[:tests]
  end

  #write users who answer correct all of questions
  def write_correct_user db, message, date
     db[:correct_users][date] << "@#{message.chat.username}"
     db.set! :correct_users, db[:correct_users]
  end

  def handle_user_test bot, db, message, chat_id, question_ids, today
    user_test = db[:tests][today][chat_id]
    if user_test && user_test[:status] ==  'testing'
      mark = user_test[:mark]
      current_question_id = user_test[:question_ids].last
      mark += 1 if message.text == db[:questions][current_question_id][:ra]
      user_test[:mark] = mark

      # update status to "tested" if user has completed all of questions
      if question_ids - user_test[:question_ids] == []
        user_test[:status] = "tested"
        write_correct_user(db, message, today) if mark == 3
        bot.api.send_message(chat_id: message.chat.id, text: "Your mark: #{mark}")
      else
        send_question bot, db, chat_id, today
      end

      db.set! :tests, db[:tests]
    end
  end

  def get_result bot, db, message_text, chat_id, date
    password = message_text.split.last
    text = if password == ENV["TELEBOTPW"]
      if winners_yesterday = db[:winners][date]
        "Nguoi chien thang trong ngay #{date}: #{winners_yesterday.join(', ')}"
      elsif date_correct_users = db[:correct_users][date]
        winners = date_correct_users.shuffle[0..2]
        db[:winners][date] = winners
        db.set! :winners, db[:winners]
        winners.join(", ")
        "Nguoi chien thang trong ngay #{date}: #{winners.join(', ')}"
      else
        "Khong co ai tra loi dung trong ngay #{date}."
      end
    else
      "Sai mat khau"
    end
    bot.api.send_message(chat_id: chat_id, text: text)
  end
end

Kyberbot.new.main();
