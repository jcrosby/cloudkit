require 'sinatra/base'
require File.dirname(__FILE__) + '/<%= @app_name %>/app'

module <%= @app_name.capitalize %>
  def self.app
    <%= @app_name.capitalize %>::App
  end
end
