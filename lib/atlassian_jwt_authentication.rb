require 'atlassian-jwt-authentication/filters'
require 'atlassian-jwt-authentication/version'
require 'atlassian-jwt-authentication/helper'
require 'atlassian-jwt-authentication/httparty'
require 'atlassian-jwt-authentication/railtie' if defined?(Rails)

module AtlassianJwtAuthentication
  include Helper
  include Filters
end