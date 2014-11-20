require './helpers/application_helper'
require 'active_support/inflector'
require 'newrelic_rpm'

class ApplicationController < Sinatra::Base

  # Available Helpers
  # include ActiveSupport::Inflector::Inflections

  helpers ApplicationHelper

  enable :logging
  enable :method_override
  enable :sessions
  # set the secret yourself, so all your application instances share it:
  set :session_secret, 'super secret'

  configure do
    uri = URI.parse(ENV["REDISTOGO_URL"])
    $redis = Redis.new({:host => uri.host,
                        :port => uri.port,
                        :password => uri.password})
    $redis.flushdb
    $redis.set("manhole:index", 0)
    ruby_object = JSON.parse(File.read('manhole_data.json'))
    ruby_object["manhole_data"].each do |manhole_entry|
      index = $redis.incr("manhole:index")
      manhole_entry[:id] = index
      $redis.set("manholes:#{index}", manhole_entry.to_json)
    end
  end

  before do
    logger.info "Request Headers: #{headers}"
    logger.warn "Params: #{params}"
  end

  after do
    logger.info "Response Headers: #{response.headers}"
  end

  #######################
  # API
  #######################

  CLIENT_ID = ENV["FB_CLIENT_ID"]
  APP_SECRET = ENV["FB_APP_SECRET"]
  if ENV['RACK_ENV'] == 'development'
    REDIRECT_URI = "http://127.0.0.1:9292/oauth_callback"
  elsif ENV['RACK_ENV'] == 'production'
    REDIRECT_URI = "http://dis-cover.herokuapp.com/oauth_callback"
  end
end
