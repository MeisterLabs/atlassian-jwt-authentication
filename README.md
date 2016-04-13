# Atlassian JWT Authentication

Atlassian JWT Authentication provides support for handling JWT authentication as required by
 Atlassian when building add-ons: https://developer.atlassian.com/static/connect/docs/latest/concepts/authentication.html

## Installation

### From Git

You can check out the latest source from git:

    git clone https://github.com/MeisterLabs/atlassian-jwt-authentication.git

Or, if you're using Bundler, just add the following to your Gemfile:

    gem 'atlassian-jwt-authentication', git: 'https://github.com/MeisterLabs/atlassian-jwt-authentication.git'

## Usage

### 1. Setup

This gem relies on the `jwt_tokens` and `jwt_users` tables being present in your database and 
the associated JwtToken and JwtUser models.

`jwt_tokens` must contain the following fields:

* `addon_key`
* `client_key`
* `shared_secret`
* `product_type`

`jwt_users` must contain the following fields:
* `user_key`
* `jwt_token_id`

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
For more information on the available Atlassian lifecycle callbacks visit https://developer.atlassian.com/static/connect/docs/latest/modules/lifecycle.html.
The gem will take care of setting up the necessary JWT tokens upon add-on installation and to
delete the appropriate tokens upon un-installation. To use this functionality, simply call
 
```ruby
include AtlassianJwtAuthentication::Filters

on_add_on_installed        # call this in your installed method
on_add_on_uninstalled      # call this in your uninstalled method
```
 
Furthermore, protect the methods that will be JWT aware by using the gem's
JWT token verification filter. You need to pass your add-on descriptor so that
the appropriate JWT shared secret can be identified:

```ruby
include AtlassianJwtAuthentication::Filters

# will render(nothing: true, status: unauthorized) if verification fails
before_filter only: [:display, :editor] do |controller|
  controller.send(:verify_jwt, 'your-add-on-key')
end
```

Methods that are protected by the `verify_jwt` filter also have access to information
about the current Atlassian user and the add-on.
```ruby
# @jwt_auth is an instance of JwtToken, so you have access to the fields described above
pp @jwt_auth.addon_key

# @jwt_user is an instance of JwtUser, so you have access to the Atlassian user_key
pp @jwt_user.user_key

# If you need more information about the Atlassian user access the @user_context hash
pp @user_context['userKey']
pp @user_context['username']
pp @user_context['displayName']
```

## Requirements

Ruby 2.0+, ActiveRecord 4.1+