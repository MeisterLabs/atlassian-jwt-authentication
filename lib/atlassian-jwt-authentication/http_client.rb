require 'faraday'

module AtlassianJwtAuthentication
  module HttpClient
    def self.new(url = nil, options = nil)
      client = Faraday.new(url, options) do |f|
        if AtlassianJwtAuthentication.debug_requests || AtlassianJwtAuthentication.log_requests
          f.response :logger, nil, bodies: AtlassianJwtAuthentication.debug_requests
        end
        f.adapter Faraday.default_adapter
      end

      if block_given?
        yield client
      end

      client
    end
  end
end