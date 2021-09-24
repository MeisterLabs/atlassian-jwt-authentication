module AtlassianJwtAuthentication
  module Middleware
    class VerifyJwtToken
      PREFIX = 'atlassian_jwt_authentication'.freeze

      JWT_TOKEN_HEADER = "#{PREFIX}.jwt_token".freeze
      JWT_CONTEXT = "#{PREFIX}.context".freeze
      JWT_ACCOUNT_ID = "#{PREFIX}.account_id".freeze
      JWT_QSH_VERIFIED = "#{PREFIX}.qsh_verified".freeze

      def initialize(app, options)
        @app = app
        @addon_key = options[:addon_key]
        @if = options[:if]
      end

      def call(env)
        # Skip if @if predicate is given and evaluates to false
        if @if && !@if.call(env)
          return @app.call(env)
        end

        request = ActionDispatch::Request.new(env)

        jwt = request.params[:jwt]

        if request.headers['authorization'].present?
          algorithm, possible_jwt = request.headers['authorization'].split(' ')
          jwt = possible_jwt if algorithm == 'JWT'
        end

        if jwt
          jwt_verification = JWTVerification.new(@addon_key, jwt, request)
          jwt_auth, account_id, context, qsh_verified = jwt_verification.verify

          if jwt_auth
            request.set_header(JWT_TOKEN_HEADER, jwt_auth)
          end

          if account_id
            request.set_header(JWT_ACCOUNT_ID, account_id)
          end

          if context
            request.set_header(JWT_CONTEXT, context)
          end

          if qsh_verified
            request.set_header(JWT_QSH_VERIFIED, qsh_verified)
          end
        end

        @app.call(env)
      end
    end
  end
end