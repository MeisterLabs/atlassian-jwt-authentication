require 'jwt'

module AtlassianJwtAuthentication
  class JWTVerification
    attr_accessor :addon_key, :jwt, :request, :exclude_qsh_params, :logger

    def initialize(addon_key, jwt, request, &block)
      self.addon_key = addon_key
      self.jwt = jwt
      self.request = request

      self.exclude_qsh_params = []
      self.logger = nil

      yield self if block_given?
    end

    def verify
      unless jwt.present? && addon_key.present?
        return false
      end

      begin
        decoded = JWT.decode(jwt, nil, false, { verify_expiration: AtlassianJwtAuthentication.verify_jwt_expiration })
      rescue => e
        log(:error, "Could not decode JWT: #{e.to_s} \n #{e.backtrace.join("\n")}")
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
        log(:error, "Could not find jwt_token for client_key #{data['iss']} and addon_key #{addon_key}")
        return false
      end

      # Discard tokens without verification
      if encoding_data['alg'] == 'none'
        log(:error, "The JWT checking algorithm was set to none for client_key #{data['iss']} and addon_key #{addon_key}")
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
        log(:error, "Error decoding JWT segments - no header and payload for client_key #{data['iss']} and addon_key #{addon_key}")
        return false
      end

      # Now verify the signature with the proper algorithm
      begin
        JWT.verify_signature(encoding_data['alg'], jwt_auth.shared_secret, signing_input, signature)
      rescue => e
        log(:error, "Could not verify the JWT signature: #{e.to_s} \n #{e.backtrace.join("\n")}")
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
            map{ |param_pair| encode_param(param_pair) }.
            join('&')

        qsh = Digest::SHA256.hexdigest(qsh)

        unless data['qsh'] == qsh
          log(:error, "QSH mismatch for client_key #{data['iss']} and addon_key #{addon_key}")
          return false
        end
      end

      context = data['context']

      # In the case of Confluence and Jira we receive user information inside the JWT token
      if data['context'] && data['context']['user']
        account_id = data['context']['user']['accountId']
      else
        account_id = data['sub']
      end

      [jwt_auth, account_id, context]
    end

    private

    def encode_param(param_pair)
      key, value = param_pair

      if value.respond_to?(:to_query)
        value.to_query(key)
      else
        ERB::Util.url_encode(key) + '=' + ERB::Util.url_encode(value)
      end
    end

    def log(level, message)
      return unless defined?(logger)

      logger.send(level.to_sym, message)
    end
  end
end