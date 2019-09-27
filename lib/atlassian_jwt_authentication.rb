require 'atlassian-jwt-authentication/verify'
require 'atlassian-jwt-authentication/middleware'
require 'atlassian-jwt-authentication/filters'
require 'atlassian-jwt-authentication/error_processor'
require 'atlassian-jwt-authentication/version'
require 'atlassian-jwt-authentication/helper'
require 'atlassian-jwt-authentication/oauth2'
require 'atlassian-jwt-authentication/user_bearer_token'
require 'atlassian-jwt-authentication/railtie' if defined?(Rails)

module AtlassianJwtAuthentication
  include Helper
  include Filters
  include ErrorProcessor

  mattr_accessor :context_path
  self.context_path = ''

  # Decode the JWT parameter without verification
  mattr_accessor :verify_jwt_expiration
  self.verify_jwt_expiration = ENV.fetch('JWT_VERIFY_EXPIRATION', 'true') != 'false'

  # Log external HTTP requests?
  mattr_accessor :log_requests
  self.log_requests = ENV.fetch('AJA_LOG_REQUESTS', 'false') == 'true'

  # Debug external HTTP requests? Log bodies
  mattr_accessor :debug_requests
  self.debug_requests = ENV.fetch('AJA_DEBUG_REQUESTS', 'false') == 'true'
end