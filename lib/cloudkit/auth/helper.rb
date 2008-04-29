module CloudKit
  module Auth
    module Helper
      def base_url
        trimmed_base_url + '/'
      end
      
      def trimmed_base_url
        "http://#{request.env['HTTP_HOST']}"
      end

      def session
        @session ||= request.env['rack.session']
      end

      def openid_consumer
        @openid_consumer ||= OpenID::Consumer.new(session, CloudKit::Auth::DbStore.new)
      end
      
      def logged_in?
        !!current_user
      end

      def current_user
        @current_user ||= (login_from_session || login_from_cookie) unless @current_user == false
      end

      def current_user=(new_user)
        session['user_id'] = new_user ? new_user.id : nil
        @current_user = new_user || false
      end

      def authorized?
        logged_in?
      end

      def login_required
        authorized? || access_denied
      end

      def access_denied
        stop ['Access Denied', 403]
      end

      def login_from_session
        self.current_user = User.find_by_id(session['user_id']) if session['user_id']
      end

      def login_from_cookie
        user = request.cookies['auth_token'] && User.find_by_remember_token(request.cookies['auth_token'])
        if user && user.remember_token?
          response.set_cookie('auth_token', { :value => user.remember_token, :expires => user.remember_token_expires_at })
          self.current_user = user
        end
      end

      def current_token
        @current_token
      end

      def current_client_application
        @current_client_application
      end

      def oauthenticate
        verified = verify_oauth_signature
        return verified && current_token.is_a?(CloudKit::Auth::AccessToken)
      end

      def oauth?
        current_token != nil
      end

      def oauth_required
        if oauthenticate
          if authorized?
            return true
          else
            invalid_oauth_response
          end
        else
          invalid_oauth_response
        end
      end

      def login_or_oauth_required
        if oauthenticate
          if authorized?
            return true
          else
            invalid_oauth_response
          end
        else
          login_required
        end
      end

      def verify_oauth_consumer_signature
        begin
          valid = ClientApplication.verify_request(request) do |token, consumer_key|
            @current_client_application = ClientApplication.find_by_key(consumer_key)
            [nil, @current_client_application.secret]
          end
        rescue
          valid = false
        end

        invalid_oauth_response unless valid
      end

      def verify_oauth_request_token
        verify_oauth_signature && current_token.is_a?(RequestToken)
      end

      def invalid_oauth_response(code=401, message="Invalid OAuth Request")
        stop [message, code]
      end

      private

      def current_token=(token)
        @current_token = token
        if @current_token
          @current_user = @current_token.user
          @current_client_application = @current_token.client_application 
        end
        @current_token
      end

      def verify_oauth_signature
        begin
          valid = CloudKit::Auth::ClientApplication.verify_request(request) do |token|
            self.current_token = CloudKit::Auth::ClientApplication.find_token(token)
            [(current_token.nil? ? nil : current_token.secret), (current_client_application.nil? ? nil : current_client_application.secret)]
          end
          valid
        end
      end
    end
  end
end