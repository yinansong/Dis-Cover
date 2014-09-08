require 'httparty'
require 'sinatra/base'
require 'redis'
require 'json'
require 'uri'
require 'pry'
require 'securerandom'

class App < Sinatra::Base

  ########################
  # Configuration
  ########################

  configure do
    enable :logging
    enable :method_override
    enable :sessions
    # set the secret yourself, so all your application instances share it:
    set :session_secret, 'super secret'

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

  CLIENT_ID = "747682725292550"
  REDIRECT_URI = "http://127.0.0.1:9292/oauth_callback"
  APP_SECRET = "2ec23b0f1c89b43edd6290397ba6d680"

  #######################
  # Routes
  #######################

  get('/add') do
    render(:erb, :add)
  end

  get('/about') do
    binding.pry
    render(:erb, :about)
  end

  get('/oauth_callback') do
    # 2 things sent back are code & state
    code = params["code"]
    state = params["state"]
    if session[:state] == state
      response = HTTParty.post(
        "https://graph.facebook.com/oauth/access_token",
        :headers => {
          "Accept" => "application/json"
        },
        :body => {
          :client_id => CLIENT_ID,
          :client_secret => APP_SECRET,
          :code => code,
          :redirect_uri => REDIRECT_URI
        }
      )
      session[:access_token] = response["access_token"]
    end
    redirect to("/")
  end

  get('logout') do
    session[:access_token] = nil
    redirect to("/")
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
    @manhole = JSON.parse($redis.get("manholes:#{@id}"))
    render(:erb, :edit)
  end
  put('/:id') do
    @id = params[:id]
    updated_manhole = {
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
      "id" => @id
    }
    $redis.set("manholes:#{@id}", updated_manhole.to_json)
    redirect to("/#{@id}")
  end

  # see a single manhole for details
  get('/:id') do
    @id = params[:id]
    @chosen_manhole = JSON.parse($redis.get("manholes:#{@id}"))
    render(:erb, :detail)
  end

  get('/') do
    # for login with facebook
    fb_base_url = "https://www.facebook.com/dialog/oauth"
    state = SecureRandom.urlsafe_base64
    session[:state] = state
    scope = "public_profile"
    @fb_login_url = "#{fb_base_url}?client_id=#{CLIENT_ID}&redirect_uri=#{REDIRECT_URI}&state=#{state}&scope=#{scope}"

    #for all the manhole covers
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @cities = @manholes.map do |manhole_entry|
      manhole_entry["city"].downcase
    end
    @number_of_cities_uniq = @cities.uniq.size
    @countries = @manholes.map do |manhole_entry|
      manhole_entry["country"]
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
