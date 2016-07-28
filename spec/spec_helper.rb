require 'rspec'

require File.dirname(__FILE__) + '/../lib/atlassian_jwt_authentication.rb'

RSpec.configure do |config|
  config.order = :random
  config.default_formatter = :documentation
end