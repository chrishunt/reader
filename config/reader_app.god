God.pid_file_directory = "/tmp/"

rails_env   = ENV['RAILS_ENV'] || "development"
rails_root  = ENV['RAILS_ROOT'] || File.expand_path('../../', __FILE__).to_s


God.watch do |w|
  w.group = "reader"
  w.name = "sidekiq"
  w.dir = "#{rails_root}"
  w.start = "bundle exec sidekiq -e #{rails_env} -C #{rails_root}/config/sidekiq.yml"
  w.stop  = "bundle exec sidekiqctl stop `cat /tmp/sidekiq/pid` 120"
  w.log = "#{rails_root}/log/sidekiq.log"
  w.keepalive
end

# For some reason private_pub needs to think it's in production env.
# On local dev environment, use dev values in production config.
God.watch do |w|
  w.group = "reader"
  w.name = "private_pub"
  w.dir = "#{rails_root}"
  w.start = "bundle exec rackup -s thin -E production #{rails_root}/private_pub.ru"
  w.log = "#{rails_root}/log/private_pub.log"
  w.keepalive
end




