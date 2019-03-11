require 'jwt'
require 'addressable'

require_relative './http_client'

module AtlassianJwtAuthentication
  module Helper
    protected

    # Returns the current JWT auth object if it exists
    def current_jwt_token
      @jwt_auth ||= session[:jwt_auth] ? JwtToken.where(id: session[:jwt_auth]).first : nil
    end

    # Sets the current JWT auth object
    def current_jwt_token=(jwt_auth)
      session[:jwt_auth] = jwt_auth.nil? ? nil : jwt_auth.id
      @jwt_auth = jwt_auth
    end

    # Returns the current JWT context if it exists
    def current_jwt_context
      @jwt_context ||= session[:jwt_context]
    end

    # Sets the current JWT context
    def current_jwt_context=(jwt_context)
      session[:jwt_context] = jwt_context
      @jwt_context = jwt_context
    end

    # Returns the current JWT account_id if it exists
    def current_account_id
      @account_id ||= session[:account_id]
    end

    # Sets the current JWT account_id
    def current_account_id=(account_id)
      session[:account_id] = account_id
      @account_id = account_id
    end

    def user_bearer_token(account_id, scopes)
      AtlassianJwtAuthentication::UserBearerToken::user_bearer_token(current_jwt_token, account_id, scopes)
    end

    def rest_api_url(method, endpoint)
      unless current_jwt_token
        raise 'Missing Authentication context'
      end

      # Expiry for the JWT token is 3 minutes from now
      issued_at = Time.now.utc.to_i
      expires_at = issued_at + 180

      qsh = Digest::SHA256.hexdigest("#{method.to_s.upcase}&#{endpoint}&")

      jwt = JWT.encode({
        qsh: qsh,
        iat: issued_at,
        exp: expires_at,
        iss: current_jwt_token.addon_key
      }, current_jwt_token.shared_secret)

      # return the service call URL with the JWT token added
      "#{current_jwt_token.api_base_url}#{endpoint}?jwt=#{jwt}"
    end

    def rest_api_call(method, endpoint, data = nil)
      url = rest_api_url(method, endpoint)
      options = {
          body: data ? data.to_json : nil,
          headers: {'Content-Type' => 'application/json'}
      }

      response = HttpClient.new(url, options).send(method)

      to_json_response(response)
    end

    def to_json_response(response)
      if response.success?
        Response.new(200, JSON::parse(response.body))
      else
        Response.new(response.status)
      end
    end

    class Response
      attr_accessor :status, :data

      def initialize(status, data = nil)
        @status = status
        @data = data
      end

      def success?
        status == 200
      end

      def failed?
        !success?
      end
    end
  end
end