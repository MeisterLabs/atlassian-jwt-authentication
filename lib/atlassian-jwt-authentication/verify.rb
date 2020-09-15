require 'jwt'

module AtlassianJwtAuthentication
  class Verify

    def self.verify_jwt(addon_key, jwt, request, exclude_qsh_params = [])
      unless jwt.present? && addon_key.present?
        return false
      end

      begin
        decoded = JWT.decode(jwt, nil, false, {verify_expiration: AtlassianJwtAuthentication.verify_jwt_expiration})
      rescue Exception => e
        return false
      end

      # Extract the data
      data = decoded[0]
      encoding_data = decoded[1]

      # Find a matching JWT token in the DB
      jwt_auth = JwtToken.where(
        client_key: data['iss'],
        addon_key: addon_key
      ).first

      unless jwt_auth
        return false
      end

      # Discard tokens without verification
      if encoding_data['alg'] == 'none'
        return false
      end

      # Verify the signature with the sharedSecret and the algorithm specified in the header's alg field
      # The JWT gem has changed the way you can access the decoded segments in v 1.5.5, we just handle both.
      if JWT.const_defined?(:Decode)
        options = {
          verify_expiration: AtlassianJwtAuthentication.verify_jwt_expiration,
          verify_not_before: true,
          verify_iss: false,
          verify_iat: false,
          verify_jti: false,
          verify_aud: false,
          verify_sub: false,
          leeway: 0
        }
        decoder = JWT::Decode.new(jwt, nil, true, options)
        header, payload, signature, signing_input = decoder.decode_segments
      else
        header, payload, signature, signing_input = JWT.decoded_segments(jwt)
      end

      unless header && payload
        return false
      end

      # Now verify the signature with the proper algorithm
      begin
        JWT.verify_signature(encoding_data['alg'], jwt_auth.shared_secret, signing_input, signature)
      rescue Exception => e
        return false
      end

      if data['qsh']
        # Verify the query has not been tampered by Creating a Query Hash and
        # comparing it against the qsh claim on the verified token
        if jwt_auth.base_url.present? && request.url.include?(jwt_auth.base_url)
          path = request.url.gsub(jwt_auth.base_url, '')
        else
          path = request.path.gsub(AtlassianJwtAuthentication::context_path, '')
        end
        path = '/' if path.empty?

        qsh_parameters = request.query_parameters.
          except(:jwt)

        exclude_qsh_params.each { |param_name| qsh_parameters = qsh_parameters.except(param_name) }

        qsh = request.method.upcase + '&' + path + '&' +
          qsh_parameters.
            sort.
            map(&method(:encode_param)).
            join('&')

        qsh = Digest::SHA256.hexdigest(qsh)

        unless data['qsh'] == qsh
          return false
        end

        qsh_verified = true
      else
        qsh_verified = false
      end

      context = data['context']

      # In the case of Confluence and Jira we receive user information inside the JWT token
      if data['context'] && data['context']['user']
        account_id = data['context']['user']['accountId']
      else
        account_id = data['sub']
      end

      [jwt_auth, account_id, context, qsh_verified]
    end

    private

    def self.encode_param(param_pair)
      key, value = param_pair

      if value.respond_to?(:to_query)
        value.to_query(key)
      else
        ERB::Util.url_encode(key) + '=' + ERB::Util.url_encode(value)
      end
    end
  end
end