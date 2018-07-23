module AtlassianJwtAuthentication
  module Middleware
    class VerifyJwtToken
      PREFIX = 'atlassian_jwt_authentication'.freeze

      def initialize(app, addon_key)
        @app = app
        @addon_key = addon_key
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        jwt = request.params[:jwt]

        if request.headers['authorization'].present?
          algorithm, possible_jwt = request.headers['authorization'].split(' ')
          jwt = possible_jwt if algorithm == 'JWT'
        end

        if jwt
          jwt_auth, jwt_user = Verify.verify_jwt(@addon_key, jwt, request, [])

          if jwt_auth
            request.set_header("#{PREFIX}.jwt_token", jwt_auth)
          end

          if jwt_user
            request.set_header("#{PREFIX}.jwt_user", jwt_user)
          end
        end

        @app.call(env)
      end
    end
  end
end