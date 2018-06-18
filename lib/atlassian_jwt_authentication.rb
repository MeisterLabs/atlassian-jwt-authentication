require 'atlassian-jwt-authentication/filters'
require 'atlassian-jwt-authentication/version'
require 'atlassian-jwt-authentication/helper'
require 'atlassian-jwt-authentication/httparty'
require 'atlassian-jwt-authentication/oauth2'
require 'atlassian-jwt-authentication/user_bearer_token'
require 'atlassian-jwt-authentication/railtie' if defined?(Rails)

module AtlassianJwtAuthentication
  include Helper
  include Filters

  mattr_accessor :context_path
  self.context_path = ''

  # Decode the JWT parameter without verification
  mattr_accessor :verify_jwt_expiration
  self.verify_jwt_expiration = ENV.fetch('JWT_VERIFY_EXPIRATION', 'true') != 'false'
end