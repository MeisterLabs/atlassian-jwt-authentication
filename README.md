# Atlassian JWT Authentication

Atlassian JWT Authentication provides support for handling JWT authentication as required by
 Atlassian when building add-ons: https://developer.atlassian.com/static/connect/docs/latest/concepts/authentication.html

## Installation

### From Git

You can check out the latest source from git:

    git clone

Or, if you're using Bundler, just add the following to your Gemfile:

    gem 'activemerchant'

## Usage

This simple example demonstrates how a purchase can be made using a person's
credit card details.

```ruby
bundle exec rails g atlassian_jwt_authentication:create_tables

```

## Requirements

Ruby 2.0+