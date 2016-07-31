require 'atlassian-jwt-authentication/filters'
require 'atlassian-jwt-authentication/version'
require 'atlassian-jwt-authentication/helper'
require 'atlassian-jwt-authentication/jwt_connection_adapter'
require 'atlassian-jwt-authentication/railtie' if defined?(Rails)

module AtlassianJwtAuthentication
  include Helper
  include Filters
end