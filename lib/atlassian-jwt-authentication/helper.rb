require 'jwt'
require 'httparty'

module AtlassianJwtAuthentication
  module Helper
    protected

    # Returns the current JWT auth object if it exists
    def current_jwt_auth
      @jwt_auth ||= session[:jwt_auth] ? JwtToken.where(id: session[:jwt_auth]).first : nil
    end

    # Sets the current JWT auth object
    def current_jwt_auth=(jwt_auth)
      session[:jwt_auth] = jwt_auth.nil? ? nil : jwt_auth.id
      @jwt_auth = jwt_auth
    end

    # Returns the current JWT User if it exists
    def current_jwt_user
      @jwt_user ||= session[:jwt_user] ? JwtUser.where(id: session[:jwt_user]).first : nil
    end

    # Sets the current JWT user
    def current_jwt_user=(jwt_user)
      session[:jwt_user] = jwt_user.nil? ? nil : jwt_user.id
      @jwt_user = jwt_user
    end

    def rest_api_url(method, endpoint)
      unless current_jwt_auth
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
                           iss: current_jwt_auth.addon_key
                       }, current_jwt_auth.shared_secret)

      # return the service call URL with the JWT token added
      "#{current_jwt_auth.api_base_url}#{endpoint}?jwt=#{jwt}"
    end

    def rest_api_call(method, endpoint, data = nil)
      response = HTTParty.send(method, rest_api_url(method, endpoint), {
          body: data ? data.to_json : nil,
          headers: {'Content-Type' => 'application/json'}
      })

      if response.success?
        Response.new(200, JSON::parse(response.body))
      else
        Response.new(response.code)
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