# Atlassian JWT Authentication

Atlassian JWT Authentication provides support for handling JWT authentication as required by
 Atlassian when building add-ons: https://developer.atlassian.com/static/connect/docs/latest/concepts/authentication.html

## Installation

### From Git

You can check out the latest source from git:

`git clone https://github.com/MeisterLabs/atlassian-jwt-authentication.git`

Or, if you're using Bundler, just add the following to your Gemfile:

```ruby
gem 'atlassian-jwt-authentication', 
  git: 'https://github.com/MeisterLabs/atlassian-jwt-authentication.git'
```

## Usage

### Setup

This gem relies on the `jwt_tokens` table being present in your database and 
the associated JwtToken model.

To create those simply use the provided generators:

```
bundle exec rails g atlassian_jwt_authentication:setup
```

If you are using another database for the JWT data storage than the default one, pass the name of the DB config to the generator:
```
bundle exec rails g atlassian_jwt_authentication:setup shared
```

Don't forget to run your migrations now!

### Controller filters

The gem provides 2 endpoints for an Atlassian add-on lifecycle, installed and uninstalled. 
For more information on the available Atlassian lifecycle callbacks visit 
https://developer.atlassian.com/static/connect/docs/latest/modules/lifecycle.html.

If your add-on baseUrl is not your application root URL then include the following 
configuration for the context path. This is needed in the query hash string validation 
step of verifying the JWT:
```ruby
# In the add-on descriptor:
# "baseUrl": "https://www.example.com/atlassian/confluence",

AtlassianJwtAuthentication.context_path = '/atlassian/confluence'
```

#### Add-on installation
The gem will take care of setting up the necessary JWT tokens upon add-on installation and to
delete the appropriate tokens upon un-installation. To use this functionality, simply call
 
```ruby
include AtlassianJwtAuthentication

before_action :on_add_on_installed, only: [:installed]
before_action :on_add_on_uninstalled, only: [:uninstalled]
```

#### Add-on authentication
Furthermore, protect the methods that will be JWT aware by using the gem's
JWT token verification filter. You need to pass your add-on descriptor so that
the appropriate JWT shared secret can be identified:

```ruby
include AtlassianJwtAuthentication

# will respond with head(:unauthorized) if verification fails
before_filter only: [:display, :editor] do |controller|
  controller.send(:verify_jwt, 'your-add-on-key')
end
```

Methods that are protected by the `verify_jwt` filter also give access to information
about the current JWT token instance and logged in account (when available):

* `current_jwt_token` returns `JwtToken`
* `current_account_id` returns `String`

Furthermore, this information is stored in the session so you will have access
to these 2 instances also on subsequent requests even if they are not JWT signed.

```ruby
# current_jwt_token returns an instance of JwtToken, so you have access to the fields described above
pp current_jwt_token.addon_key
pp current_jwt_token.base_url
```

If you need detailed user information you need to obtain it from the instance and process it respecting GDPR.

#### How to send a signed HTTP request from the iframe back to the add-on service

The initial call to load the iframe content is secured by JWT. However, the loaded content cannot
sign subsequent requests. A typical example is content that makes AJAX calls back to the add-on. Cookie sessions cannot
be used, as many browsers block third-party cookies by default. AJA provides middleware that
works without cookies and helps making secure requests from the iframe.

Standard JWT tokens are used to authenticate requests from the iframe back to the add-on service. A route can be secured
using the following code:

```ruby
include AtlassianJwtAuthentication

before_filter only: [:protected] do |controller|
 controller.send(:verify_jwt, 'your-add-on-key', skip_qsh_verification: true)
end
```

In order to secure your route, the token must be part of the HTTP request back to the add-on service. This can be done
by using the standard `jwt` query parameter:

```html
<a href="/protected?jwt={{token}}">See more</a>
```

The second option is to use the Authorization HTTP header, e.g. for AJAX requests:

```javascript
beforeSend: function(request) {
  request.setRequestHeader("Authorization", "JWT {{token}}");
}
```

You can embed the token anywhere in your iframe content using the `token` content variable. For example, you can embed
it in a meta tag, from where it can later be read by a script:

```html
<meta name="token" content="{{token}}">

#### Add-on licensing
If your add-on has a licensing model you can use the `ensure_license` filter to check for a valid license.
As with the `verify_jwt` filter, this simply responds with an unauthorized header if there is no valid license
for the installation.

```ruby
before_filter :ensure_license
```
If your add-on was for free and you're just adding licensing now, you can specify
the version at which you started charging, ie. the minimum version of the add-on
for which you require a valid license. Simply include the code below with your version
string in the controller that includes the other add-on code.
```ruby
def min_licensing_version
  Gem::Version.new('1.0.0')
end
```

### Middleware

You can use a middleware to verify JWT tokens (for example in Rails `application.rb`):

```ruby
config.middleware.insert_after ActionDispatch::Session::CookieStore, AtlassianJwtAuthentication::Middleware::VerifyJwtToken, 'your_addon_key'
```

Token will be taken from params or `Authorization` header, if it's verified successfully request will have following headers set:

* atlassian_jwt_authorization.jwt_token `JwtToken` instance
* atlassian_jwt_authorization.account_id `String` instance
* atlassian_jwt_authorization.context `Hash` instance

Middleware will not block requests with invalid or missing JWT tokens, you need to use another layer for that.

### Making a service call

Build the URL required to make a service call with the `rest_api_url` helper or
make a service call with the `rest_api_call` helper that will handle the request for you.
Both require the method and the endpoint that you need to access:

```ruby
# Get available project types
url = rest_api_url(:get, '/rest/api/2/project/type')
response = Faraday.get(url)

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

### User impersonification

To make requests on user's behalf add `act_as_user` in scopes required by your app. 

Later you can obtain [OAuth bearer token](https://developer.atlassian.com/cloud/jira/software/oauth-2-jwt-bearer-token-authorization-grant-type/) from Atlassian.

Do that using `AtlassianJwtAuthentication::UserBearerToken.user_bearer_token(account_id, scopes)`

### Logging

If you want to debug the JWT verification define a logger in the controller where you're including `AtlassianJwtAuthentication`:

```ruby
def logger
  Logger.new("#{Rails.root}/log/atlassian_jwt.log")
end
``` 

### Custom error handling

If you want to render your own pages when the add-on throws one of the following errors:
- forbidden
- unauthorized
- payment_required

overwrite the following methods in your controller:

```ruby
def render_forbidden
  # do your own handling there
  # render your own template 
  render(template: '...', layout: '...')
end

# the same for render_payment_required and render_unauthorized

```

## Installing the add-on

You can use rake tasks to simplify plugin installation:

```ruby
bin/rails atlassian:install[prefix,email,api_token,https://external.address.to/descriptor]
```

Where `prefix` is your instance name before `.atlassian.net`. You an get an [API token](https://confluence.atlassian.com/cloud/api-tokens-938839638.html) from [Manage your account](https://id.atlassian.com/manage/api-tokens) page.

## Configuration

Config | Environment variable | Description | Default |
------ | -------------------- | ----------- | ------- |
`AtlassianJwtAuthentication.context_path` | none | server path your app is running at | `''` 
`AtlassianJwtAuthentication.verify_jwt_expiration` | `JWT_VERIFY_EXPIRATION` | when `false` allow expired tokens, speeds up development, especially combined with webpack hot module reloading | `true` 
`AtlassianJwtAuthentication.log_requests` | `AJA_LOG_REQUESTS` | when `true` outgoing HTTP requests will be logged | `false` 
`AtlassianJwtAuthentication.debug_requests` | `AJA_DEBUG_REQUESTS` | when `true` HTTP requests will include body content, implicitly turns on `log_requests` | `false` 
`AtlassianJwtAuthentication.signed_install` | `AJA_SIGNED_INSTALL` | Installation lifecycle security improvements. Migration process described [here](https://community.developer.atlassian.com/t/action-required-atlassian-connect-installation-lifecycle-security-improvements/49046). In the descriptor set `"apiMigrations":{"signed-install":AtlassianJwtAuthentication.signed_install}`  | `false`

### Middleware configuration

Parameter | Description /
--------- |-------------|
`force_asymmetric_verify` | A `proc` expected to return 'true' if the currently processed request must be validated with RS256 algorithm. Used for _signed_install_ endpoints.

## Requirements

Ruby 2.0+, ActiveRecord 4.1+

## Integrations

### Message Bus

With middleware enabled you can use following configuration to limit access to message bus per user / instance:
```ruby
MessageBus.user_id_lookup do |env|
  env.try(:[], 'atlassian_jwt_authentication.account_id')
end

MessageBus.site_id_lookup do |env|
  env.try(:[], 'atlassian_jwt_authentication.jwt_token').try(:id)
end
```

Then use `MessageBus.publish('/test', 'message', site_id: X, user_ids: [Y])` to publish message only for a user.

Requires message_bus patch available at https://github.com/HeroCoders/message_bus/commit/cd7c752fe85a17f7e54aa950a94d7c6378a55ed1


## Upgrade guide

### Version 0.7.x

Removed `current_jwt_user`, `JwtUser`, update your code to use `current_account_id`

### Versions < 0.6.x

`current_jwt_auth` has been renamed to `current_jwt_token` to match model name. Either mass rename or add `alias` in your controller:

```ruby
alias_method :current_jwt_auth, :current_jwt_token
helper_method :current_jwt_auth
```