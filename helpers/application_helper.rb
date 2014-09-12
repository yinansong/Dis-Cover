module ApplicationHelper

  def formatted_title(title)
    "<h1>#{title}</h1>"
  end

  # options hash for id and class
  def link_to(title, path, options={})
    "<a href=\"#{path}\">#{title}</a>"
  end

  def image_tag(source, option={})
    attributes = options.map {|key, value| "#{key}=\"#{value}\""}.join(' ')
    "<img src=\"#{source}\" #{attributes}>"
  end

  def logged_in?
    session[:access_token] != nil
  end

end
