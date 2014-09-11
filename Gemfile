# A sample Gemfile
source "https://rubygems.org"

ruby "2.1.2"

gem 'sinatra', '1.4.5', require: 'sinatra/base'
gem 'redis',  '3.1.0'
gem 'httparty'
gem 'rack'

# only used in development locally
group :development, :test do
  gem 'pry'
  gem 'shotgun'
end

group :production do
  # gems specific just in the production environment
end

group :test do
  gem 'rspec'
  gem 'capybara'
end
