require 'httparty'
require 'sinatra/base'
require 'redis'
require 'json'
require 'uri'
# require 'pry'
require 'securerandom'
require 'rss'
require 'rack/utils'

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

  CLIENT_ID = ENV["FB_CLIENT_ID"]
  APP_SECRET = ENV["FB_APP_SECRET"]
  REDIRECT_URI = "http://127.0.0.1:9292/oauth_callback"

  #######################
  # Routes
  #######################


  get('/rss/:id') do
    id = params[:id]
    rss = RSS::Maker.make("atom") do |maker|
      maker.channel.author = "Yinan Song"
      maker.channel.updated = Time.now.to_s
      maker.channel.about = "http://aqueous-forest-9034.herokuapp.com/rss"
      maker.channel.title = "Dis-Cover"
      maker.items.new_item do |item|
        item.link = "/manholecovers/#{id}"
        item.title = "Just another manhole cover!"
        item.updated = Time.now.to_s
      end
    end
    puts rss
    @rss = rss
    render(:erb, @rss.to_s)
  end

  # Error Handling
  not_found do
    'This is nowhere to be found.'
    redirect to('/')
  end
  error 405 do
    'Access forbidden'
    redirect to('/')
  end

  get('/blog') do
    # instagram feed part
    tagged_w_manholecover_all = HTTParty.get("https://api.instagram.com/v1/tags/manhole/media/recent?client_id=a0d18232c4ae42cd8ddb1343a263cd32")
    @tagged_w_manholecover = tagged_w_manholecover_all["data"]
      # @tagged_w_manholecover is an array

    # show all the blogposts
    render(:erb, :blog)
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
      # binding.pry if manhole_entry["province_or_state"].nil?
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
            :app_id => CLIENT_ID,
            :code => code,
            :redirect_uri => REDIRECT_URI
          },
          :headers => {
            "Accept" => "application/json"
          }
        )
        query_hash = Rack::Utils.parse_nested_query(response)
        session[:access_token] = query_hash["access_token"]
       end
    redirect to("/")
  end

  get('/users') do
    HTTParty.get("https://graph.facebook.com /{user-id}")
  end

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
    color = @chosen_manhole["color"]
    manholes_of_same_color = @manholes.select do |manhole_entry|
      manhole_entry["color"] == "#{color}"
    end
    @random_manhole_of_same_color1 = manholes_of_same_color.sample
    @random_manhole_of_same_color2 = manholes_of_same_color.sample
    @random_manhole_of_same_color3 = manholes_of_same_color.sample
    render(:erb, :detail)
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
    @manhole_samples = @manholes.sample(20)

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

  get('/') do
    redirect to('/manholecovers')
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
  end

end
