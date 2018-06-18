module AtlassianJwtAuthentication
  module HTTParty
    include ::HTTParty
    
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def get_with_jwt(path, options = {}, &block)
        perform_request_with_jwt Net::HTTP::Get, path, options, &block
      end

      def post_with_jwt(path, options = {}, &block)
        perform_request_with_jwt Net::HTTP::Post, path, options, &block
      end

      def patch_with_jwt(path, options = {}, &block)
        perform_request_with_jwt Net::HTTP::Patch, path, options, &block
      end

      def put_with_jwt(path, options = {}, &block)
        perform_request_with_jwt Net::HTTP::Put, path, options, &block
      end

      def delete_with_jwt(path, options = {}, &block)
        perform_request_with_jwt Net::HTTP::Delete, path, options, &block
      end

      def move_with_jwt(path, options = {}, &block)
        perform_request_with_jwt Net::HTTP::Move, path, options, &block
      end

      def copy_with_jwt(path, options = {}, &block)
        perform_request_with_jwt Net::HTTP::Copy, path, options, &block
      end

      def head_with_jwt(path, options = {}, &block)
        ensure_method_maintained_across_redirects options
        perform_request_with_jwt Net::HTTP::Head, path, options, &block
      end

      def options_with_jwt(path, options = {}, &block)
        perform_request_with_jwt Net::HTTP::Options, path, options, &block
      end

      def mkcol_with_jwt(path, options = {}, &block)
        perform_request_with_jwt Net::HTTP::Mkcol, path, options, &block
      end

      def perform_request_with_jwt(http_method, path, options, &block)
        perform_request(http_method, path, normalize_options(http_method, path, options), &block)
      end

      def prepare_canonical_query_string(options = {})
        all = {}.merge(options.fetch(:query, {}))

        if options.has_key?(:body) && options[:body].respond_to?(:to_hash)
          all = all.merge(options.fetch(:body, {}))
        end

        all.keys.sort.map do |key|
          if all[key].is_a? Enumerable
            sorted_params = all[key].sort.map { |_| Addressable::URI.encode_component(_, Addressable::URI::CharacterClasses::UNRESERVED) }
            param_value = sorted_params.join ','
          else
            param_value = Addressable::URI.encode_component(all[key].to_s, Addressable::URI::CharacterClasses::UNRESERVED)
          end

          Addressable::URI.encode_component(key) + '=' + param_value
        end.join '&'
      end

      def prepare_jwt_token(method, endpoint, options)
        current_jwt_auth = options[:current_jwt_auth]
        unless current_jwt_auth
          raise 'Missing Authentication context'
        end

        # Expiry for the JWT token is 3 minutes from now
        issued_at = Time.now.utc.to_i
        expires_at = issued_at + 180

        qsh = "#{method::METHOD.to_s.upcase}&#{endpoint}&#{prepare_canonical_query_string(options)}"

        JWT.encode({
          qsh: Digest::SHA256.hexdigest(qsh),
          iat: issued_at,
          exp: expires_at,
          iss: current_jwt_auth.addon_key
        }, current_jwt_auth.shared_secret)
      end

      def normalize_options(http_method, path, options)
        if options[:user_key]
          user_bearer = AtlassianJwtAuthentication::UserBearerToken::user_bearer_token(
            options[:current_jwt_auth],
            options[:user_key],
            [])["access_token"]
          options.merge(
            headers: options.fetch(:headers, {}).merge(
              authorization: "Bearer #{user_bearer}"
            )
          )
        else
          options.merge(
            query: options.fetch(:query, {}).merge(
              jwt: prepare_jwt_token(http_method, path, options)
            )
          )
        end
      end
    end
  end
end
