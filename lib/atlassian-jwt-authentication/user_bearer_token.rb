module AtlassianJwtAuthentication
  module UserBearerToken
    def self.user_bearer_token(current_jwt_token, account_id, scopes)
      scopes_key = (scopes || []).map(&:downcase).sort.uniq.join(',')
      cache_key = "jwt_token/#{current_jwt_token.id}/user/#{account_id}:scopes:/#{scopes_key}"

      read_from_cache = ->(refresh = false) do
        Rails.cache.fetch(cache_key, force: refresh) do
          AtlassianJwtAuthentication::Oauth2::get_access_token(current_jwt_token, account_id, scopes).tap do |token_details|
            token_details["expires_at"] = Time.now.utc.to_i + token_details["expires_in"] - 3.seconds # some leeway
          end
        end
      end

      access_token = read_from_cache.call(false)
      if access_token["expires_at"] <= Time.now.utc.to_i
        access_token = read_from_cache.call(true)
      end
      access_token
    end
  end
end