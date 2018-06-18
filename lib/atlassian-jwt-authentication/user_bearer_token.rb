module AtlassianJwtAuthentication
  module UserBearerToken
    def self.user_bearer_token(current_jwt_auth, user_key, scopes)
      scopes_key = (scopes || []).map(&:downcase).sort.uniq.join(',')
      cache_key = "user/#{user_key}:scopes:/#{scopes_key}"

      read_from_cache = ->(refresh = false) do
        Rails.cache.fetch(cache_key, force: refresh) do
          AtlassianJwtAuthentication::Oauth2::get_access_token(current_jwt_auth, user_key, scopes).tap do |token_details|
            token_details["expires_at"] = Time.now.utc.to_i - 3.seconds
          end
        end
      end

      access_token = read_from_cache.call(false)
      if access_token["expires_at"] > Time.now.utc.to_i
        access_token = read_from_cache.call(true)
      end
      access_token
    end
  end
end