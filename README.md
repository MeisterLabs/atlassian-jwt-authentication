# Atlassian JWT Authentication

Atlassian JWT Authentication provides support for handling JWT authentication as required by
 Atlassian when building add-ons: https://developer.atlassian.com/static/connect/docs/latest/concepts/authentication.html

## Installation

### From Git

You can check out the latest source from git:

    git clone https://github.com/MeisterLabs/atlassian-jwt-authentication.git

Or, if you're using Bundler, just add the following to your Gemfile:

    gem 'atlassian-jwt-authentication', 
                    git: 'https://github.com/MeisterLabs/atlassian-jwt-authentication.git', 
                    require: 'atlassian_jwt_authentication'

## Usage

### 1. Setup

This gem relies on the `jwt_tokens` and `jwt_users` tables being present in your database and 
the associated JwtToken and JwtUser models.

`jwt_tokens` must contain the following fields:

* `addon_key`
* `client_key`
* `shared_secret`
* `product_type`
* `base_url`

`jwt_users` must contain the following fields:
* `jwt_token_id`
* `user_key`
* `name`
* `display_name`

You can also simply use the provided generators that will create the tables and the models for you:

```ruby
bundle exec rails g atlassian_jwt_authentication:setup
```

If you are using another database for the JWT data storage than the default one, pass the name of the DB config to the generator:
```ruby
bundle exec rails g atlassian_jwt_authentication:setup shared
```

Don't forget to run your migrations now!

### 2. Controller filters

The gem provides 2 endpoints for an Atlassian add-on lifecycle, installed and uninstalled. 
For more information on the available Atlassian lifecycle callbacks visit 
https://developer.atlassian.com/static/connect/docs/latest/modules/lifecycle.html.
The gem will take care of setting up the necessary JWT tokens upon add-on installation and to
delete the appropriate tokens upon un-installation. To use this functionality, simply call
 
```ruby
before_action :on_add_on_installed, only: [:installed]
before_action :on_add_on_uninstalled, only: [:uninstalled]
```
 
Furthermore, protect the methods that will be JWT aware by using the gem's
JWT token verification filter. You need to pass your add-on descriptor so that
the appropriate JWT shared secret can be identified:

```ruby
include AtlassianJwtAuthentication::Filters

# will respond with head(:unauthorized) if verification fails
before_filter only: [:display, :editor] do |controller|
  controller.send(:verify_jwt, 'your-add-on-key')
end
```

Methods that are protected by the `verify_jwt` filter also have access to information
about the current JWT authentication instance and the JWT user (when available).
Furthermore, this information is stored in the session so you will have access
to these 2 instances also on subsequent requests even if they are not JWT signed.

```ruby
# current_jwt_auth returns an instance of JwtToken, so you have access to the fields described above
pp current_jwt_auth.addon_key

# current_jwt_user is an instance of JwtUser, so you have access to the Atlassian user information.
Beware, this information is not present when developing for Bitbucket.
pp current_jwt_user.user_key
pp current_jwt_user.name
pp current_jwt_user.display_name
```

### 3. Making a service call

Build the URL required to make a service call with the `rest_api_url` helper or
make a service call with the `rest_api_call` helper that will handle the request for you.
Both require the method and the endpoint that you need to access:

```ruby
# Get available project types
url = rest_api_url('GET', '/rest/api/2/project/type')
response = HTTParty.get(url)

# Create an issue
data = {
    fields: {
        project: {
            'id': 10100
        },
        summary: 'This is an issue summary',
        issuetype: {
            id: 10200
        }
    }
}

response = rest_api_call(:post, '/rest/api/2/issue', data)
pp response.success?

```

## Requirements

Ruby 2.0+, ActiveRecord 4.1+