module AtlassianJwtAuthentication
  module Filters
    def self.included
      pp 'included'
    end

    def verify_jwt
      unless params[:jwt].present?
        render(nothing: true, status: :unauthorized)
        return
      end

      decoded = JWT.decode(params[:jwt], nil, false)

      data = decoded[0]
      encoding_data = decoded[1]
      jwt_token = JwtToken.where(
          client_key: data['iss'],
          user_key: data['context']['user']['userKey']
      ).first

      unless jwt_token
        render(nothing: true, status: :unauthorized)
        return
      end

      # Verify the signature with the sharedSecret and the algorithm specified in the header's alg field
      header, payload, signature, signing_input = JWT.decoded_segments(params[:jwt])
      unless header && payload
        render(nothing: true, status: :unauthorized)
        return
      end

      begin
        JWT.verify_signature(encoding_data['alg'], jwt_token.shared_secret, signing_input, signature)
      rescue Exception => e
        render(nothing: true, status: :unauthorized)
        return
      end

      true
    end
  end
end