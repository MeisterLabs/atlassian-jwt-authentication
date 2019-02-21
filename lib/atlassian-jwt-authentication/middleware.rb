module AtlassianJwtAuthentication
  module Middleware
    class VerifyJwtToken
      PREFIX = 'atlassian_jwt_authentication'.freeze

      JWT_TOKEN_HEADER = "#{PREFIX}.jwt_token".freeze
      JWT_USER_HEADER = "#{PREFIX}.jwt_user".freeze
      JWT_CONTEXT = "#{PREFIX}.context".freeze
      JWT_ACCOUNT_ID = "#{PREFIX}.account_id".freeze

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
          jwt_auth, jwt_user, context = Verify.verify_jwt(@addon_key, jwt, request, [])

          if jwt_auth
            request.set_header(JWT_TOKEN_HEADER, jwt_auth)
          end

          if jwt_user
            request.set_header(JWT_USER_HEADER, jwt_user)
            request.set_header(JWT_ACCOUNT_ID, jwt_user.account_id) if jwt_user.respond_to?(:account_id)
          end

          if context
            request.set_header(JWT_CONTEXT, context)
          end
        end

        @app.call(env)
      end
    end
  end
end