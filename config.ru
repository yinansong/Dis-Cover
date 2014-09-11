require 'rubygems'
require 'bundler'

# require 'httparty'
# require 'sinatra/base'
# require 'redis'
# require 'json'
# require 'uri'
# require 'pry' if ENV['RACK_ENV'] == 'development'
# require 'securerandom'
# require 'rss'
# require 'rack/utils'
# takes care of that!
Bundler.require(:default, ENV["RACK_ENV"].to_sym)

require './app'

run App


