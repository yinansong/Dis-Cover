require 'rubygems'
require 'bundler'

# require 'httparty', 'sinatra/base', 'redis', 'json', 'uri', 'pry' (if ENV['RACK_ENV'] == 'development'), 'securerandom', 'rss', 'rack/utils' in one line
Bundler.require(:default, ENV["RACK_ENV"].to_sym)

require './app'

run App


