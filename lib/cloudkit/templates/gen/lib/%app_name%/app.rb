module <%= @app_name.capitalize %>
  class App < Sinatra::Base

    get '/' do
      erb :index
    end

  end
end
