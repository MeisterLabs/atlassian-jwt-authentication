$:.push File.expand_path('../lib', __FILE__)
require 'atlassian-jwt-authentication/version'

Gem::Specification.new do |s|
  s.platform     = Gem::Platform::RUBY
  s.name         = 'atlassian-jwt-authentication'
  s.version      = AtlassianJwtAuthentication::VERSION
  s.summary      = 'DB architecture and controller filters for dealing with Atlassian\'s JWT authentication'
  s.description  = 'Atlassian JWT Authentication provides support for handling JWT authentication as required by Atlassian when building add-ons: https://developer.atlassian.com/static/connect/docs/latest/concepts/authentication.html'
  s.license      = 'MIT'

  s.author = 'Laura Barladeanu'
  s.email = 'laura@meisterlabs.com'
  s.homepage = 'http://meisterlabs.com/'

  s.required_ruby_version = '>= 2'

  s.files = Dir['CHANGELOG', 'README.md', 'MIT-LICENSE', 'lib/**/*']
  s.require_path = 'lib'

  s.add_dependency('addressable', '>= 2.4.0')
  s.add_dependency('faraday', '>= 0.11')
  s.add_dependency('jwt', '~> 1.5')

  s.add_development_dependency('activerecord', '>= 4.1.0')
  s.add_development_dependency('bundler')
  s.add_development_dependency('generator_spec')
  s.add_development_dependency('rake')
  s.add_development_dependency('rspec')
end
