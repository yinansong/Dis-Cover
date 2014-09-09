require 'httparty'
require 'sinatra/base'
require 'redis'
require 'json'
require 'uri'
require 'pry'
require 'securerandom'
require 'rss'

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


  # get('/rss') do
  #   rss = RSS::Maker.make("atom") do |maker|
  #     maker.channel.author = "matz"
  #     maker.channel.updated = Time.now.to_s
  #     maker.channel.about = "http://www.ruby-lang.org/en/feeds/news.rss"
  #     maker.channel.title = "Dis-Cover"
  #     maker.items.new_item do |item|
  #       item.link = "http://www.ruby-lang.org/en/news/2010/12/25/ruby-1-9-2-p136-is-released/"
  #       item.title = "Ruby 1.9.2-p136 is released"
  #       item.updated = Time.now.to_s
  #     end
  #   end
  # puts rss
  # end

  # Error Handling
  not_found do
    'This is nowhere to be found.'
    redirect to('/')
  end
  error 405 do
    'Access forbidden'
    redirect to('/')
  end

  get('/manholecovers/add') do
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    render(:erb, :add)
  end

  get('/tag/:tagname') do
    @tagname = params[:tagname]
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @with_tagname_array = @manholes.select do |manhole_entry|
      manhole_entry["tags"].split(", ").include?"#{@tagname}"
    end
    render(:erb, :tag)
  end

  get('/year/:year') do
    @year = params[:year].to_i
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @same_year_array = @manholes.select do |manhole_entry|
      manhole_entry["year"] == @year
    end
    render(:erb, :year)
  end

  get('/color/:color') do
    @color = params[:color]
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @certain_color_array = @manholes.select do |manhole_entry|
      manhole_entry["color"] == @color
    end
    render(:erb, :color)
  end

  get('/shape/:shape') do
    @shape = params[:shape]
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @certain_shape_array = @manholes.select do |manhole_entry|
      manhole_entry["shape"] == @shape
    end
    render(:erb, :shape)
  end

  get('/country/:country') do
    @country = params[:country].downcase
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @certain_country_array = @manholes.select do |manhole_entry|
      manhole_entry["country"].downcase == @country
    end
    render(:erb, :country)
  end

  get('/province_or_state/:province_or_state') do
    @province_or_state = params["province_or_state"].downcase.split("+").join(" ")
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @certain_province_or_state_array = @manholes.select do |manhole_entry|
      manhole_entry["province_or_state"].downcase == @province_or_state
    end
    render(:erb, :province_or_state)
  end

  get('/city/:city') do
    @city = params[:city].downcase
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @certain_city_array = @manholes.select do |manhole_entry|
      manhole_entry["city"].downcase == @city
    end
    render(:erb, :city)
  end

  get('/about') do
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    render(:erb, :about)
  end

  get('/oauth_callback') do
    # 2 things sent back are code & state
    code = params[:code]
    state = params[:state]
       if session[:state] == state
        response = HTTParty.get(
          "https://graph.facebook.com/oauth/access_token",
          :query => {
            :client_id => CLIENT_ID,
            :client_secret => APP_SECRET,
            :code => code,
            :redirect_uri => REDIRECT_URI
          },
          :headers => {
            "Accept" => "application/json"
          }
        )
        session[:access_token] = response.to_s.split("&")[0].split("=")[1]
      end
    redirect to("/")
  end

  # get('/users') do
  #   HTTParty.get("https://graph.facebook.com /{user-id}")
  # end

  get('/logout') do
    session[:access_token] = nil
    redirect to("/")
  end

  # delete a manhole cover entry
  get('/manholecovers/:id/delete') do
    @id = params[:id]
    $redis.del("manholes:#{@id}")
    redirect to("/manholecovers")
  end

  # edit a manhole cover entry
  get('/manholecovers/:id/edit') do
    @id = params[:id]
    @manhole = JSON.parse($redis.get("manholes:#{@id}"))
    render(:erb, :edit)
  end
  put('/manholecovers/:id') do
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
    redirect to("/manholecovers/#{@id}")
  end

  # see a single manhole for details
  get('/manholecovers/:id') do
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @id = params[:id]
    @chosen_manhole = JSON.parse($redis.get("manholes:#{@id}"))
    render(:erb, :detail)
  end

  get('/') do
    redirect to('/manholecovers')
  end

  get('/manholecovers') do
    # for login with facebook
    fb_base_url = "https://www.facebook.com/dialog/oauth"
    state = SecureRandom.urlsafe_base64
    session[:state] = state
    scope = "public_profile"
    @fb_login_url = "#{fb_base_url}?client_id=#{CLIENT_ID}&redirect_uri=#{REDIRECT_URI}&state=#{state}&scope=#{scope}"

    #for a sample of all the manhole covers
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @manhole_samples = @manholes.sample(10)

    #for the data in the summary line
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
  post('/manholecovers') do
    index = $redis.incr("manhole:index")
    new_manhole = {
      "img" => params[:img],
      "country" => params[:coutry],
      "state_or_province" => params[:state_or_province],
      "city" => params[:city],
      "year" => params[:year],
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
