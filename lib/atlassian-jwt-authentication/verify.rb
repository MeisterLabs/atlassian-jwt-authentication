require 'jwt'

module AtlassianJwtAuthentication
  class JWTVerification
    attr_accessor :addon_key, :jwt, :audience, :request, :exclude_qsh_params, :logger

    def initialize(addon_key, audience, jwt, request, &block)
      self.addon_key = addon_key
      self.audience = audience
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

      # First decode the token without signature & claims verification
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

      # Discard the tokens without verification
      if encoding_data['alg'] == 'none'
        log(:error, "The JWT checking algorithm was set to none for client_key #{data['iss']} and addon_key #{addon_key}")
        return false
      end

      if AtlassianJwtAuthentication.signed_install && encoding_data['alg'] == 'RS256'
        response = Faraday.get("https://connect-install-keys.atlassian.com/#{encoding_data['kid']}")
        unless response.success? && response.body
          log(:error, "Error retrieving atlassian public key. Response code #{response.status} and kid #{encoding_data['kid']}")
          return false
        end

        decode_key = OpenSSL::PKey::RSA.new(response.body)
        decode_options = {algorithms: ['RS256'], verify_aud: true, aud: audience}
      else
        decode_key = jwt_auth.shared_secret
        decode_options = {}
      end

      # Decode the token again, this time with signature & claims verification
      options = JWT::DefaultOptions::DEFAULT_OPTIONS.merge(verify_expiration: AtlassianJwtAuthentication.verify_jwt_expiration).merge(decode_options)
      decoder = JWT::Decode.new(jwt, decode_key, true, options)
      begin
        payload, header = decoder.decode_segments
      rescue JWT::VerificationError
        log(:error, "Error decoding JWT segments - signature is invalid")
        return false
      rescue JWT::ExpiredSignature
        log(:error, "Error decoding JWT segments - signature is expired at #{data['exp']}")
        return false
      end

      unless header && payload
        log(:error, "Error decoding JWT segments - no header and payload for client_key #{data['iss']} and addon_key #{addon_key}")
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

        qsh_parameters = request.query_parameters.except(:jwt)

        exclude_qsh_params.each { |param_name| qsh_parameters = qsh_parameters.except(param_name) }

        qsh = request.method.upcase + '&' + path + '&' +
            qsh_parameters.
                sort.
                map{ |param_pair| encode_param(param_pair) }.
                join('&')

        qsh = Digest::SHA256.hexdigest(qsh)

        qsh_verified = data['qsh'] == qsh
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

    def encode_param(param_pair)
      key, value = param_pair

      if value.respond_to?(:to_query)
        value.to_query(key)
      else
        ERB::Util.url_encode(key) + '=' + ERB::Util.url_encode(value)
      end
    end

    def log(level, message)
      return if logger.nil?

      logger.send(level.to_sym, message)
    end
  end
end
