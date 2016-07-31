module AtlassianJwtAuthentication
  class JwtRequest < HTTParty::Request
    def prepare_canonical_query_string(query = {})
      query.keys.sort.map do |key|
        if query[key].is_a? Enumerable
          sorted_params = query[key].sort.map { |_| Addressable::URI.encode_component(_, Addressable::URI::CharacterClasses::UNRESERVED) }
          param_value = sorted_params.join ','
        else
          param_value = query[key]
        end

        Addressable::URI.encode_component(key) + '=' + param_value
      end.join '&'
    end

    def current_jwt_auth
      options[:current_jwt_auth]
    end

    def prepare_jwt_token(method, endpoint, query)
      unless current_jwt_auth
        raise 'Missing Authentication context'
      end

      # Expiry for the JWT token is 3 minutes from now
      issued_at = Time.now.utc.to_i
      expires_at = issued_at + 180

      qsh = "#{method::METHOD.to_s.upcase}&#{endpoint}&#{prepare_canonical_query_string(query)}"

      JWT.encode({
                   qsh: Digest::SHA256.hexdigest(qsh),
                   iat: issued_at,
                   exp: expires_at,
                   iss: current_jwt_auth.addon_key
                 }, current_jwt_auth.shared_secret)
    end

    def normalize_query(query)
      qs = super
      qs + '&jwt=' + prepare_jwt_token(http_method, path, query)
    end
  end
end
