namespace :atlassian do
  desc 'Install plugin descriptor into Atlassian Cloud product'
  task :install, :prefix, :username, :password, :descriptor_url do |task, args|
    require 'faraday'
    require 'json'

    def check_status(prefix, auth, status)
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

        response = Faraday.get("https://#{prefix}.atlassian.net/#{status['links']['self']}", {
            basic_auth: auth
        })

        if response.status == 303
          puts 'Plugin was successfully installed'
          return
        end

        check_status(prefix, auth, JSON.parse(response.body))
      end
    end

    auth = {username: args.username, password: args.password}
    response = Faraday.get("https://#{args.prefix}.atlassian.net/rest/plugins/1.0/", {basic_auth: auth})
    if response.success?
      token = response.headers['upm-token']

      response = Faraday.post("https://#{args.prefix}.atlassian.net/rest/plugins/1.0/",
                               {
                                   query: {token: token},
                                   basic_auth: auth,
                                   headers: {
                                       'Content-Type' => 'application/vnd.atl.plugins.remote.install+json'
                                   },
                                   body: {pluginUri: args.descriptor_url}.to_json
                               })
      payload = JSON.parse(response.body)
      check_status(args.prefix, auth, payload)
    else
      puts "Cannot get UPM token: #{response.code}"
    end
  end
end
