require 'jwt'

module AtlassianJwtAuthentication
  module Filters
    protected

    def on_add_on_installed
      # Add-on key that was installed into the Atlassian Product,
      # as it appears in your add-on's descriptor.
      addon_key = params[:key]

      # Identifying key for the Atlassian product instance that the add-on was installed into.
      # This will never change for a given instance, and is unique across all Atlassian product tenants.
      # This value should be used to key tenant details in your add-on.
      client_key = params[:clientKey]

      # Use this string to sign outgoing JWT tokens and validate incoming JWT tokens.
      shared_secret = params[:sharedSecret]

      # Identifies the category of Atlassian product, e.g. Jira or Confluence.
      product_type = params[:productType]

      # The base URL of the instance
      base_url = params[:baseUrl]
      api_base_url = params[:baseApiUrl] || base_url

      jwt_auth = JwtToken.where(client_key: client_key, addon_key: addon_key).first
      if jwt_auth
        # The add-on was previously installed on this client
        return false unless _verify_jwt(addon_key)
      else
        self.current_jwt_auth = JwtToken.new(jwt_token_params)
      end

      current_jwt_auth.addon_key = addon_key
      current_jwt_auth.shared_secret = shared_secret
      current_jwt_auth.product_type = "atlassian:#{product_type}"
      current_jwt_auth.base_url = base_url if current_jwt_auth.respond_to?(:base_url)
      current_jwt_auth.api_base_url = api_base_url if current_jwt_auth.respond_to?(:api_base_url)

      current_jwt_auth.save!

      # BitBucket sends user details on installation
      [:principal, :user].each do |key|
        if params[key].present?
          user = params[key]
          if user[:username].present? && user[:display_name].present? &&
              user[:uuid].present? && user[:type].present? && user[:type] == 'user'

            jwt_user = current_jwt_auth.jwt_users.where(user_key: user[:uuid]).first
            JwtUser.create(jwt_token_id: current_jwt_auth.id,
                           user_key: user[:uuid],
                           name: user[:username],
                           display_name: user[:display_name]) unless jwt_user
          end
        end
      end

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
      _verify_jwt(addon_key, true)
    end

    def ensure_license
      unless params[:lic] && params[:lic] == 'active'
        head(:unauthorized)
        return false
      end

      unless current_jwt_auth
        raise 'current_jwt_auth missing, add the verify_jwt filter'
      end

      response = rest_api_call(:get, "/rest/atlassian-connect/1/addons/#{current_jwt_auth.addon_key}")
      unless response.success? && response.data &&
          response.data['state'] == 'ENABLED' &&
          response.data['license'] && response.data['license']['active']
        head(:unauthorized)
        return false
      end

      true
    end

    private

    def _verify_jwt(addon_key, consider_param = false)
      self.current_jwt_auth = nil
      self.current_jwt_user = nil

      jwt = nil

      # The JWT token can be either in the Authorization header
      # or can be sent as a parameter. During the installation
      # handshake we only accept the token coming in the header
      if consider_param
        jwt = params[:jwt] if params[:jwt].present?
      elsif !request.headers['authorization'].present?
        head(:unauthorized)
        return false
      end

      if request.headers['authorization'].present?
        algorithm, jwt = request.headers['authorization'].split(' ')
        jwt = nil unless algorithm == 'JWT'
      end

      unless jwt.present? && addon_key.present?
        head(:unauthorized)
        return false
      end

      # Decode the JWT parameter without verification
      decoded = JWT.decode(jwt, nil, false)

      # Extract the data
      data = decoded[0]
      encoding_data = decoded[1]

      # Find a matching JWT token in the DB
      jwt_auth = JwtToken.where(
          client_key: data['iss'],
          addon_key: addon_key
      ).first

      unless jwt_auth
        head(:unauthorized)
        return false
      end

      # Discard tokens without verification
      if encoding_data['alg'] == 'none'
        head(:unauthorized)
        return false
      end

      # Verify the signature with the sharedSecret and the algorithm specified in the header's alg field
      # The JWT gem has changed the way you can access the decoded segments in v 1.5.5, we just handle both.
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
        head(:unauthorized)
        return false
      end

      # Now verify the signature with the proper algorithm
      begin
        JWT.verify_signature(encoding_data['alg'], jwt_auth.shared_secret, signing_input, signature)
      rescue Exception => e
        head(:unauthorized)
        return false
      end

      # Verify the query has not been tampered by Creating a Query Hash and
      # comparing it against the qsh claim on the verified token
      if jwt_auth.base_url.present? && request.url.include?(jwt_auth.base_url)
        path = request.url.gsub(jwt_auth.base_url, '')
      else
        path = request.path.gsub(context_path, '')
      end
      path = '/' if path.empty?

      qsh_parameters = request.query_parameters.
          except(:jwt)

      exclude_qsh_params.each { |param_name| qsh_parameters = qsh_parameters.except(param_name) }

      qsh = request.method.upcase + '&' + path + '&' +
          qsh_parameters.
              sort.
              map{ |param_pair| ERB::Util.url_encode(param_pair[0]) + '=' + ERB::Util.url_encode(param_pair[1]) }.join('&')
      qsh = Digest::SHA256.hexdigest(qsh)

      unless data['qsh'] == qsh
        head(:unauthorized)
        return
      end

      self.current_jwt_auth = jwt_auth

      # In the case of Confluence and Jira we receive user information inside the JWT token
      if data['context'] && data['context']['user']
        # Has this user accessed our add-on before?
        # If not, create a new JwtUser

        self.current_jwt_user = current_jwt_auth.jwt_users.where(user_key: data['context']['user']['userKey']).first
        self.current_jwt_user = JwtUser.create(jwt_token_id: current_jwt_auth.id,
                                               user_key: data['context']['user']['userKey'],
                                               name: data['context']['user']['username'],
                                               display_name: data['context']['user']['displayName']) unless current_jwt_user
      elsif params[:user_uuid]
        self.current_jwt_user = current_jwt_auth.jwt_users.where(user_key: params[:user_uuid]).first
      end

      true
    end

    def jwt_token_params
      {
          client_key: params.permit(:clientKey)['clientKey'],
          addon_key: params.permit(:key)['key']
      }
    end

    def exclude_qsh_params
      []
    end
  end
end