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
    $redis.set("manhole:index", 0)

    ruby_object = JSON.parse(File.read('manhole_data.json'))
    ruby_object["manhole_data"].each do |manhole_entry|
      # Setting an index by incrementing a counter rather than using keys.size
      index = $redis.incr("manhole:index")
      manhole_entry[:id] = index
      # keys.count and each_with_index won't work properly because there's no guarantee of order with a hash
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

  ########################
  # Routes
  ########################

  get('/') do
    @manholes = $redis.keys("*manholes*").map { |manhole_entry| JSON.parse($redis.get(manhole_entry)) }
    render(:erb, :index)
  end

  get('/add') do
    render(:erb, :add)
  end

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
    new_index = @@manholes.size + 1
    $redis.set("manholes:#{new_index}", new_manhole.to_json)
    redirect to('/')
  end

end
