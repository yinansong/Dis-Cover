require 'sinatra/base'
require 'redis'
require 'json'
require 'uri'
require 'pry'

class App < Sinatra::Base

  ########################
  # Configuration
  ########################

  configure do
    enable :logging
    enable :method_override
    enable :sessions

    uri = URI.parse(ENV["REDISTOGO_URL"])
    $redis = Redis.new({:host => uri.host,
                        :port => uri.port,
                        :password => uri.password})
    $redis.flushdb
    ruby_object = JSON.parse(File.read('manhole_data.json'))
    counter = $redis.keys.size + 1
    ruby_object["manhole_data"].each do |manhole_entry|
      $redis.set("manholes:#{counter}", manhole_entry.to_json)
      counter += 1
    end
  end

  before do
    logger.info "Request Headers: #{headers}"
    logger.warn "Params: #{params}"
  end

  after do
    logger.info "Response Headers: #{response.headers}"
  end

  ########################
  # Routes
  ########################

  get('/add') do
    render(:erb, :add)
  end

  get('/about') do
    render(:erb, :about)
  end

  # see a single manhole for details
  get('/:id') do
    @manholes = $redis.keys.map { |key| JSON.parse($redis.get(key)) }
    id = params[:id]
    @chosen_manhole = JSON.parse($redis["manholes:#{id}"])
    @true_id = @manholes.index(@chosen_manhole)
    render(:erb, :detail)
  end

  get('/') do
    @manholes = $redis.keys.map { |key| JSON.parse($redis.get(key)) }
    render(:erb, :index)
  end

  # add a new manhole cover
  post('/') do
    new_manhole = {
      "img" => params[:img],
      "country" => params[:coutry],
      "state_or_province" => params[:state_or_province],
      "city" => params[:city],
      "year" => params[:year],
      "color" => params[:color],
      "color" => params[:color],
      "shape" => params[:shape],
      "note" => params[:note],
      "tags" => params[:tags]
    }
    new_index = $redis.keys.size + 1
    $redis.set("manholes:#{new_index}", new_manhole.to_json)
    redirect to('/')
  end

end
