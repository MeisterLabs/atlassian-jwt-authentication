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

This gem relies on the `jwt_tokens` table being present in your database and the associated JwtToken model.
The expected fields are:

* `addon_key`
* `client_key`
* `shared_secret`
* `product_type`
* `user_key`

Or you can use the provided generators that will create the table and/or the model for you:

```ruby
bundle exec rails g atlassian_jwt_authentication:create_table
bundle exec rails g atlassian_jwt_authentication:create_model

```

## Requirements

Ruby 2.0+, ActiveRecord 4.1+