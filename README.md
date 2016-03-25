# Atlassian JWT Authentication

Atlassian JWT Authentication provides support for handling JWT authentication as required by
 Atlassian when building add-ons: https://developer.atlassian.com/static/connect/docs/latest/concepts/authentication.html

## Installation

### From Git

You can check out the latest source from git:

    git clone https://github.com/MeisterLabs/atlassian-jwt-authentication.git

Or, if you're using Bundler, just add the following to your Gemfile:

    gem 'atlassian-jwt-authentication'

## Usage

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

You can use the provided generators that will create the table and/or the model for you:

```ruby
bundle exec rails g atlassian_jwt_authentication:setup
```

If you are using another database for the JWT data storage than the default one, pass the name of the DB config to the generator:
```ruby
bundle exec rails g atlassian_jwt_authentication:setup shared
```

Don't forget to run your migrations now!

## Requirements

Ruby 2.0+, ActiveRecord 4.1+