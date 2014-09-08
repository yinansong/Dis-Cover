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
  # Routes
  #######################

  get('/add') do
    render(:erb, :add)
  end

  get('/about') do
    render(:erb, :about)
  end

  # delete a manhole cover entry
  get('/:id/delete') do
    @id = params[:id]
    $redis.del("manholes:#{@id}")
    redirect to("/")
  end

  # edit a manhole cover entry
  get('/:id/edit') do
    @id = params[:id]
    $redis.del("manholes:#{@id}")
    redirect to("/#{@id}")
  end

  # see a single manhole for details
  get('/:id') do
    @id = params[:id]
    @chosen_manhole = JSON.parse($redis.get("manholes:#{@id}"))
    render(:erb, :detail)
  end

  get('/') do
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @cities = @manholes.map do |manhole_entry|
      manhole_entry["city"].downcase
    end
    @number_of_cities_uniq = @cities.uniq.size
    @countries = @manholes.map do |manhole_entry|
      manhole_entry["country"].downcase
    end
    @number_of_countries_uniq = @countries.uniq.size
    render(:erb, :index)
  end

  # add a new manhole cover
  post('/') do
    index = $redis.incr("manhole:index")
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
      "tags" => params[:tags],
      "id" => index,
    }
    $redis.set("manholes:#{index}", new_manhole.to_json)
    redirect to('/')
  end

end
