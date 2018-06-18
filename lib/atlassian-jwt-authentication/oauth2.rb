module AtlassianJwtAuthentication
  module Oauth2
    EXPIRE_IN_SECONDS = 60
    AUTHORIZATION_SERVER_URL = "https://auth.atlassian.io"
    JWT_CLAIM_PREFIX = "urn:atlassian:connect"
    GRANT_TYPE = "urn:ietf:params:oauth:grant-type:jwt-bearer"
    SCOPE_SEPARATOR = ' '

    def self.get_access_token(current_jwt_auth, user_key, scopes = nil)
      form_data = {
        grant_type: GRANT_TYPE,
        assertion: prepare_jwt_token(current_jwt_auth, user_key)
      }

      if scopes
        form_data[:scopes] = scopes.join(SCOPE_SEPARATOR).upcase
      end

      HTTParty.post(AUTHORIZATION_SERVER_URL + "/oauth2/token", body: form_data).parsed_response
    end

    def self.prepare_jwt_token(current_jwt_auth, user_key)
      unless current_jwt_auth
        raise 'Missing Authentication context'
      end

      unless user_key
        raise 'Missing User key'
      end

      # Expiry for the JWT token is 3 minutes from now
      issued_at = Time.now.utc.to_i
      expires_at = issued_at + EXPIRE_IN_SECONDS

      JWT.encode({
        iss: JWT_CLAIM_PREFIX + ":clientid:" + current_jwt_auth.oauth_client_id,
        sub: JWT_CLAIM_PREFIX + ":userkey:" + user_key,
        tnt: current_jwt_auth.base_url,
        aud: AUTHORIZATION_SERVER_URL,
        iat: issued_at,
        exp: expires_at,
      }, current_jwt_auth.shared_secret)
    end
  end
end