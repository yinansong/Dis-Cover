require './application_controller'

class App < ApplicationController

  get('/as/:id') do
    content_type :json
    @id = params[:id]
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @chosen_manhole = JSON.parse($redis.get("manholes:#{@id}"))
    {
      "img" => @chosen_manhole["img"],
      "country" => @chosen_manhole["country"],
      "state_or_province" => @chosen_manhole["state_or_province"],
      "city" => @chosen_manhole["city"],
      "year" => @chosen_manhole["year"],
      "color" => @chosen_manhole["color"],
      "shape" => @chosen_manhole["shape"],
      "note" => @chosen_manhole["note"],
      "tags" => @chosen_manhole["tags"],
      "id" => @id
    }.to_json
  end

  get('/rss') do
    content_type 'text/xml'
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    data_size = @manholes.size
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
    render(:erb, :"manholecovers/index")

    rss = RSS::Maker.make("atom") do |maker|
      maker.channel.author = "Yinan Song"
      maker.channel.updated = Time.now.to_s
      if ENV['RACK_ENV'] == 'development'
        maker.channel.about = "http://127.0.0.1:9292/rss"
      elsif ENV['RACK_ENV'] == 'production'
        maker.channel.about = "http://dis-cover.herokuapp.com/rss"
      end
      maker.channel.title = "Dis-Cover"

      maker.items.new_item do |item|
        item.id = "summary"
        item.link = "/manholecovers"
        item.title = "#{data_size} manhole covers from #{@number_of_cities_uniq} cities of #{@number_of_countries_uniq} countries currently"
        item.updated = Time.now.to_s
      end

      @manholes.each do |manhole|
        maker.items.new_item do |item|
          item.id = manhole["id"].to_s
          item.link = "/manholecovers/#{manhole["id"]}"
          item.title = "No.#{manhole["id"]}: #{manhole["year"]}, #{manhole["city"]}, #{manhole["state_or_province"]}, #{manhole["country"]}"
          item.updated = Time.now.to_s
        end
      end
    end
    rss.to_s
  end

  # Error Handling
  not_found do
    "This is nowhere to be found."
    redirect to('/')
  end

  error 405 do
    "Access forbidden."
    redirect to('/')
  end

  get('/blog') do
    # instagram feed part
    tagged_w_manholecover_all = HTTParty.get("https://api.instagram.com/v1/tags/manhole/media/recent?client_id=a0d18232c4ae42cd8ddb1343a263cd32")
    @tagged_w_manholecover = tagged_w_manholecover_all["data"]
      # @tagged_w_manholecover is an array

    # show all the blogposts
    render(:erb, :"blogs/index")
  end

  get('/manholecovers/add') do
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    render(:erb, :"manholecovers/new")
  end

  get('/tag/:tagname') do
    @tagname = params[:tagname]
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @with_tagname_array = @manholes.select do |manhole_entry|
      manhole_entry["tags"].split(", ").include?"#{@tagname}"
    end
    render(:erb, :"manholecovers/tag")
  end

  get('/year/:year') do
    @year = params[:year].to_i
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @same_year_array = @manholes.select do |manhole_entry|
      manhole_entry["year"] == @year
    end
    render(:erb, :"manholecovers/year")
  end

  get('/color/:color') do
    @color = params[:color]
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @certain_color_array = @manholes.select do |manhole_entry|
      manhole_entry["color"] == @color
    end
    render(:erb, :"manholecovers/color")
  end

  get('/shape/:shape') do
    @shape = params[:shape]
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @certain_shape_array = @manholes.select do |manhole_entry|
      manhole_entry["shape"] == @shape
    end
    render(:erb, :"manholecovers/shape")
  end

  get('/country/:country') do
    @country = params[:country]
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @certain_country_array = @manholes.select do |manhole_entry|
      manhole_entry["country"] == @country
    end
    render(:erb, :"manholecovers/country")
  end

  get('/state_or_province/:state_or_province') do
    @state_or_province = params["state_or_province"].downcase.split("+").join(" ")
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @certain_state_or_province_array = @manholes.select do |manhole_entry|
      manhole_entry["state_or_province"].downcase == @state_or_province
    end
    render(:erb, :"manholecovers/state_or_province")
  end

  get('/city/:city') do
    @city = params[:city].downcase
    @manholes = $redis.keys("*manholes*").map { |manhole| JSON.parse($redis.get(manhole)) }
    @certain_city_array = @manholes.select do |manhole_entry|
      manhole_entry["city"].downcase == @city
    end
    render(:erb, :"manholecovers/city")
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
    render(:erb, :"manholecovers/edit")
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

    # get an array of all the tags
    @array_of_tags = @chosen_manhole["tags"].split(", ")
    color = @chosen_manhole["color"]
    manholes_of_same_color = @manholes.select do |manhole_entry|
      manhole_entry["color"] == "#{color}"
    end
    @random_manhole_of_same_color1 = manholes_of_same_color.sample
    @random_manhole_of_same_color2 = manholes_of_same_color.sample
    @random_manhole_of_same_color3 = manholes_of_same_color.sample
    render(:erb, :"manholecovers/show")
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
    render(:erb, :"manholecovers/index")
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
