# coding: utf-8
require 'jekyll'

# Extend string to allow for bold text.
class String
  def bold
    "\033[1m#{self}\033[0m"
  end
end

namespace "build" do
  task :dev, [:host, :port] do |t, args|
    ENV["JEKYLL_ENV"] = "development"

    args.with_defaults(:host => "127.0.0.1", :port => "4000")
    host = args[:host]
    port = args[:port]

    system "bundle exec jekyll build --config _config.yml,_config_dev.yml"
  end
  task :prod do
    ENV["JEKYLL_ENV"] = "production"
	  system "bundle exec jekyll build --config _config.yml,_config_prod.yml"
  end
end

task :clean do
  puts 'Cleaning up _site...'.bold
  Jekyll::Commands::Clean.process({})
end