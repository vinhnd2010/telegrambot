ssh root@178.128.92.193 <<-'ENDSSH'
  cd telegrambot
  echo "=== Start fetching from Github ..."
  git pull origin master
  echo "=== Fetch source code done!"
  echo "=== Start deploying ..."
  echo "=== Bundle install ..."
  bundle
  ruby assistant.rb
  echo "Done!"
ENDSSH
