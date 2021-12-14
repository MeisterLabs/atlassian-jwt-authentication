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
        if jwt_auth.id != current_jwt_token.id
          # Update request was issued to another plugin
          render_forbidden
          return false
        end
      else
        self.current_jwt_token = JwtToken.new(jwt_token_params)
      end

      current_jwt_token.addon_key = addon_key
      current_jwt_token.shared_secret = shared_secret
      current_jwt_token.product_type = "atlassian:#{product_type}"
      current_jwt_token.base_url = base_url if current_jwt_token.respond_to?(:base_url)
      current_jwt_token.api_base_url = api_base_url if current_jwt_token.respond_to?(:api_base_url)
      current_jwt_token.oauth_client_id = params[:oauthClientId] if current_jwt_token.respond_to?(:oauth_client_id)
      current_jwt_token.public_key = params[:publicKey] if current_jwt_token.respond_to?(:public_key)
      current_jwt_token.sen = params[:supportEntitlementNumber] if current_jwt_token.respond_to?(:sen)
      current_jwt_token.payload = params.to_unsafe_h if current_jwt_token.respond_to?(:payload)

      current_jwt_token.save!

      true
    end

    def on_add_on_uninstalled
      addon_key = params[:key]

      return unless _verify_jwt(addon_key)

      client_key = params[:clientKey]

      return false unless client_key.present?

      JwtToken.where(client_key: client_key, addon_key: addon_key).destroy_all

      true
    end

    def verify_jwt(addon_key, skip_qsh_verification: false)
      _verify_jwt(addon_key, true, skip_qsh_verification: skip_qsh_verification)
    end

    def ensure_license
      unless current_jwt_token
        raise 'current_jwt_token missing, add the verify_jwt filter'
      end

      response = rest_api_call(:get, "/rest/atlassian-connect/1/addons/#{current_jwt_token.addon_key}")
      unless response.success? && response.data
        log(:error, "Client #{current_jwt_token.client_key}: API call to get the license failed with #{response.status}")
        render_payment_required
        return false
      end

      current_version = Gem::Version.new(response.data['version'])

      if min_licensing_version && current_version > min_licensing_version || !min_licensing_version
        # do we need to check for licensing on this add-on version?
        unless params[:lic] && params[:lic] == 'active'
          log(:error, "Client #{current_jwt_token.client_key}: no active license was found in the params")
          render_payment_required
          return false
        end

        unless response.data['state'] == 'ENABLED' &&
            response.data['license'] && response.data['license']['active']
          log(:error, "client #{current_jwt_token.client_key}: no active & enabled license was found")
          render_payment_required
          return false
        end
      end

      log(:info, "Client #{current_jwt_token.client_key}: license OK")

      true
    end

    private

    def _verify_jwt(addon_key, consider_param = false, skip_qsh_verification: false)
      self.current_jwt_token = nil
      self.current_account_id = nil
      self.current_jwt_context = nil

      jwt = nil

      # The JWT token can be either in the Authorization header
      # or can be sent as a parameter. During the installation
      # handshake we only accept the token coming in the header
      if consider_param
        jwt = params[:jwt] if params[:jwt].present?
      elsif !request.headers['authorization'].present?
        log(:error, 'Missing authorization header')
        render_unauthorized
        return false
      end

      if request.headers['authorization'].present?
        algorithm, possible_jwt = request.headers['authorization'].split(' ')
        jwt = possible_jwt if algorithm == 'JWT'
      end

      jwt_verification = AtlassianJwtAuthentication::JWTVerification.new(addon_key, nil, nil, jwt, request)
      jwt_verification.exclude_qsh_params = exclude_qsh_params
      jwt_verification.logger = logger if defined?(logger)

      jwt_auth, account_id, context, qsh_verified = jwt_verification.verify

      unless jwt_auth && (qsh_verified || skip_qsh_verification)
        render_unauthorized
        return false
      end

      self.current_jwt_token = jwt_auth
      self.current_account_id = account_id
      self.current_jwt_context = context

      true
    end

    def jwt_token_params
      {
          client_key: params.permit(:clientKey)['clientKey'],
          addon_key: params.permit(:key)['key']
      }
    end

    # This can be overwritten in the including controller
    def exclude_qsh_params
      []
    end

    # This can be overwritten in the including controller
    def min_licensing_version
      nil
    end

    def log(level, message)
      return unless defined?(logger)

      logger.send(level.to_sym, message)
    end
  end
end
