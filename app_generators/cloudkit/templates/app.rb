require 'yaml'
require 'erb'
require 'active_record'

configure do
  ActiveRecord::Base.logger = Logger.new('log/' + Sinatra::Application.default_options[:env].to_s + '.log')
  ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read(File.dirname(__FILE__) + '/db/config.yml')).result)
  ActiveRecord::Base.establish_connection(Sinatra::Application.default_options[:env])
end

require 'cloudkit'

helpers do
  include CloudKit::Auth::Helper
end

get '/' do
  'Insert amazing content here. <a href="/sessions/new">login</a>'
end

get '/sessions/new' do
  erb :new_session
end

post '/sessions' do
  begin
    response = openid_consumer.begin params['openid_url']
  rescue => e
    puts "error was #{e}"
    session['error'] = e
    erb :new_session
    return
  end

  session['remember_me'] = params['remember_me']
  redirect_url = response.redirect_url(base_url, base_url + 'open_id_complete')
  redirect redirect_url
end

get '/open_id_complete' do
  begin
    idp_response = openid_consumer.complete params, base_url + 'open_id_complete'
  rescue => e
    session['error'] = e
    erb :new_session
    return
  end
  
  if session['user_id'] = CloudKit::Auth::User.find_or_create_by_identity_url(idp_response.endpoint.claimed_id).id
    if logged_in?
      if session['remember_me'] == "1"
        current_user.remember_me unless current_user.remember_token?
        response.set_cookie('auth_token', {:value => current_user.remember_token , :expires => current_user.remember_token_expires_at})
      end
      session['notice'] = 'You have been logged in.'
      redirect '/ui'
    else
      session['error'] = 'Could not log on with your OpenID'
      redirect '/sessions/new'
    end
  else
    session['error'] = 'Could not log on with your OpenID'
    redirect '/sessions/new'
  end
end

get '/ui' do
  erb :ui
end

get '/oauth_clients' do
  @client_applications = current_user.client_applications
  @tokens = current_user.tokens.find(:all, :conditions => 'oauth_tokens.invalidated_at is null and oauth_tokens.authorized_at is not null')
  erb :oauth_clients_index
end

get '/oauth_clients/new' do
  @client_application = CloudKit::Auth::ClientApplication.new
  erb :oauth_clients_new
end

post '/oauth_clients' do
  @client_application = current_user.client_applications.build(:name => params['name'], :url => params['url'], :callback_url => params['callback_url'], :support_url => params['support_url'])
  puts "client application is #{@client_application.inspect}"
  if @client_application.save
    session['notice'] = 'Registered the information successfully'
    redirect "/oauth_clients/#{@client_application.id}"
  else
    erb :oauth_clients_new
  end
end

put '/oauth_clients/:id' do
  @client_application = current_user.client_applications.find(params['id'])
  if @client_application.update_attributes(params['client_application'])
    session['notice'] = 'Updated the client information successfully'
    redirect "/oauth_clients/#{@client_application.id}"
  else
    erb :oauth_clients_edit
  end
end

get '/oauth_clients/:id' do
  @client_application = current_user.client_applications.find(params['id'])
  erb :oauth_clients_show
end

get '/oauth_clients/edit' do
  @client_application = current_user.client_applications.find(params['id'])
  erb :oauth_clients_edit
end

delete '/oauth_client/:id' do
  @client_application = current_user.client_applications.find(params['id'])
  @client_application.destroy
  session['notice'] = 'Destroyed the client application registration'
  redirect '/oauth_clients'
end

post '/oauth/request_token' do
  verify_oauth_consumer_signature
  @token = current_client_application.create_request_token
  if @token
    @token.to_query
  else
    [nil, 401]
  end
end

get '/oauth/authorize' do
  login_required
  @token = CloudKit::Auth::RequestToken.find_by_token params['oauth_token']
  unless @token.invalidated?
    erb :oauth_auth
  else
    erb :oauth_auth_failure
  end
end
  
post '/oauth/authorize' do
  login_required
  @token = CloudKit::Auth::RequestToken.find_by_token params['oauth_token']
  unless @token.invalidated?
    if params['authorize'] == '1'
      @token.authorize!(current_user)
      redirect_url = params['oauth_callback'] || @token.client_application.callback_url
      if redirect_url
        redirect redirect_url + "?oauth_token=#{@token.token}"
      else
        erb :oauth_auth_success
      end
    elsif params['authorize'] == '0'
      @token.invalidate!
      erb :oauth_auth_failure
    end
  else
    erb :oauth_auth_failure
  end
end

get '/oauth/access_token' do
  verify_oauth_request_token
  @token = current_token.exchange!
  if @token
    @token.to_query
  else
    [nil, 401]
  end
end

get '/oauth/echo' do
  login_or_oauth_required
  params.collect{ |k,v| "#{k}=#{v}" }.join('&')
end
