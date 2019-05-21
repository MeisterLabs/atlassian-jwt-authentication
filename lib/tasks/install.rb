require 'atlassian-jwt-authentication/http_client'

namespace :atlassian do
  desc 'Install plugin descriptor into Atlassian Cloud product'
  task :install, :prefix, :email, :api_token, :descriptor_url do |task, args|
    require 'faraday'
    require 'json'

    connection =
      AtlassianJwtAuthentication::HttpClient.new("https://#{args.prefix}.atlassian.net") do |f|
        f.basic_auth args.email, args.api_token
      end

    def check_status(connection, status)
      if status['userInstalled']
        puts 'Plugin was successfully installed'

      elsif status.fetch('status', {})['done']
        if status.fetch('status', {})['subCode']
          puts "Error installing the plugin #{status['status']['subCode']}"
        else
          puts 'Plugin was successfully installed'
        end

      else
        wait_for = [status['pingAfter'], 5].min
        puts "waiting #{wait_for} seconds for plugin to load..."
        sleep(wait_for)

        response = connection.get(status['links']['self'])

        if response.status == 303
          puts 'Plugin was successfully installed'
          return
        end

        check_status(connection, JSON.parse(response.body))
      end
    end

    response = connection.get("/rest/plugins/1.0/")
    if response.success?
      token = response.headers['upm-token']

      response = connection.post("/rest/plugins/1.0/", {pluginUri: args.descriptor_url}.to_json, 'Content-Type' => 'application/vnd.atl.plugins.remote.install+json') do |req|
        req.params['token'] = token
      end

      payload = JSON.parse(response.body)
      check_status(connection, payload)
    else
      puts "Cannot get UPM token: #{response.status}"
    end
  end
end
