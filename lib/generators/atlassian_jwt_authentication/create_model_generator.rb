module AtlassianJwtAuthentication
  class CreateModelGenerator < Rails::Generators::Base
    desc 'Create the model necessary for the filters defined by this gem to work.'

    def self.source_root
      @source_root ||= File.expand_path('../templates', __FILE__)
    end

    def create_model
      template 'model.rb', File.join('app/models', '', 'jwt_token.rb')
    end
  end
end

