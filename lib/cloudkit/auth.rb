# OpenID - ported from OpenIdAuthentication Rails/AR plugin
require 'auth/association'
require 'auth/db_store'
require 'auth/nonce'
require 'auth/user'

# OAuth - ported from OAuth Rails/AR plugin
require 'auth/oauth_token'
require 'auth/access_token'
require 'auth/client_application'
require 'auth/oauth_nonce'
require 'auth/request_token'

gem 'oauth', '>=0.2.4'
require 'oauth'
require 'oauth/request_proxy/rack_request'
require 'oauth/server'

# Utilities ported from Restful Authentication and OAuth Plugin
require 'auth/helper'
