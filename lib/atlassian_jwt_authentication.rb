require 'atlassian-jwt-authentication/filters'
require 'atlassian-jwt-authentication/version'
require 'atlassian-jwt-authentication/helper'

module AtlassianJwtAuthentication
  include Helper
  include Filters
end