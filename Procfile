web: bundle exec puma -C config/puma.rb
release: bundle exec rails db:migrate
jobs: bundle exec rake solid_queue:start
