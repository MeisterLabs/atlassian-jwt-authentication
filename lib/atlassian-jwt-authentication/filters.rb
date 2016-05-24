require 'jwt'

module AtlassianJwtAuthentication
  module Filters
    protected

    def on_add_on_installed
      # Add-on key that was installed into the Atlassian Product, as it appears in your add-on's descriptor.
      addon_key = params[:key]

      # Identifying key for the Atlassian product instance that the add-on was installed into.
      # This will never change for a given instance, and is unique across all Atlassian product tenants.
      # This value should be used to key tenant details in your add-on
      client_key = params[:clientKey]

      # Use this string to sign outgoing JWT tokens and validate incoming JWT tokens
      shared_secret = params[:sharedSecret]

      # Identifies the category of Atlassian product, e.g. jira or confluence.
      product_type = params[:productType]

      @jwt_auth = JwtToken.where(client_key: client_key, addon_key: addon_key).first
      if @jwt_auth
        # The add-on was previously installed on this client
        return false unless _verify_jwt(addon_key)
      else
        @jwt_auth = JwtToken.new(jwt_token_params)
      end

      @jwt_auth.addon_key = addon_key
      @jwt_auth.shared_secret = shared_secret
      @jwt_auth.product_type = "atlassian:#{product_type}"

      @jwt_auth.save!

      true
    end

    def on_add_on_uninstalled
      addon_key = params[:key]

      return unless _verify_jwt(addon_key)

      client_key = params[:clientKey]

      return false unless client_key.present?

      auths = JwtToken.where(client_key: client_key, addon_key: addon_key)
      auths.each do |auth|
        auth.destroy
      end

      true
    end

    def verify_jwt(addon_key)
      return false unless _verify_jwt(addon_key, true)

      unless @user_context
        render(nothing: true, status: :unauthorized)
        return false
      end

      # Is this an Atlassian user we haven't seen before?
      @jwt_user = @jwt_auth.jwt_users.where(user_key: @user_context['userKey']).first
      @jwt_user = JwtUser.create(jwt_token_id: @jwt_auth.id, user_key: @user_context['userKey']) unless @jwt_user

      # Everything's alright
      true
    end

    private

    def _verify_jwt(addon_key, consider_param = false)
      pp addon_key
      jwt = nil

      if consider_param
        jwt = params[:jwt] if params[:jwt].present?
      elsif !request.headers['authorization'].present?
        render(nothing: true, status: :unauthorized)
        return false
      end

      if request.headers['authorization'].present?
        algorithm, jwt = request.headers['authorization'].split(' ')
        jwt = nil unless algorithm == 'JWT'
      end

      unless jwt.present? && addon_key.present?
        render(nothing: true, status: :unauthorized)
        return false
      end

      # Decode the JWT parameter without verification
      pp jwt
      decoded = JWT.decode(jwt, nil, false)
      pp decoded

      # Extract the data
      data = decoded[0]
      encoding_data = decoded[1]

      # Find a matching JWT token in the DB
      @jwt_auth = JwtToken.where(
          client_key: data['iss'],
          addon_key: addon_key
      ).first

      unless @jwt_auth
        render(nothing: true, status: :unauthorized)
        return false
      end

      # Discard tokens without verification
      if encoding_data['alg'] == 'none'
        render(nothing: true, status: :unauthorized)
        return false
      end

      # Verify the signature with the sharedSecret and the algorithm specified in the header's alg field
      if JWT.const_defined?(:Decode)
        options = {
            verify_expiration: true,
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
        render(nothing: true, status: :unauthorized)
        return false
      end

      begin
        JWT.verify_signature(encoding_data['alg'], @jwt_auth.shared_secret, signing_input, signature)
      rescue Exception => e
        render(nothing: true, status: :unauthorized)
        return false
      end

      # Has this user accessed our add-on before?
      # If not, create a new JwtUser
      @user_context = data['context']['user']

      true
    end

    def jwt_token_params
      {
          client_key: params.permit(:clientKey)['clientKey'],
          addon_key: params.permit(:key)['key']
      }
    end
  end
end