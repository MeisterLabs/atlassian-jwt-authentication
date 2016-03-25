module AtlassianJwtAuthentication
  module Filters
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

      user_key = params[:user_key]

      JwtToken.create_or_update(
          addon_key: addon_key,
          client_key: client_key,
          shared_secret: shared_secret,
          product_type: "atlassian:#{product_type}",
          user_key: user_key
      )
    end

    def on_add_on_uninstalled
      return false unless params[:clientKey].present?

      jwt_token = JwtToken.where(client_key: params[:clientKey], user_key: params[:user_key]).first
      jwt_token.destroy if jwt_token
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