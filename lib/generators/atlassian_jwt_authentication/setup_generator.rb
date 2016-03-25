require 'rails/generators/active_record'

module AtlassianJwtAuthentication
  class SetupGenerator < Rails::Generators::Base
    include Rails::Generators::Migration
    desc 'Create a migration to add atlassian jwt specific fields to your model.'
    argument :database_name, required: false,
             type: :string,
             desc: 'Additional database name configuration, if different from `database.yml`'

    def self.source_root
      @source_root ||= File.expand_path('../templates', __FILE__)
    end

    def self.next_migration_number(dirname)
      next_migration_number = current_migration_number(dirname) + 1
      ActiveRecord::Migration.next_migration_number(next_migration_number)
    end

    def self.current_migration_number(dirname) #:nodoc:
      migration_lookup_at(dirname).collect do |file|
        File.basename(file).split('_').first.to_i
      end.max.to_i
    end

    def self.migration_lookup_at(dirname) #:nodoc:
      Dir.glob("#{dirname}/[0-9]*_*.rb")
    end

    def generate_migration
      migration_template 'jwt_tokens_migration.rb.erb', "db/#{database_name.present? ? "db_#{database_name}/" : ''}migrate/create_atlassian_jwt_tokens.rb"
      migration_template 'jwt_users_migration.rb.erb', "db/#{database_name.present? ? "db_#{database_name}/" : ''}migrate/create_atlassian_jwt_users.rb"
    end

    def generate_models
      template 'jwt_token.rb', File.join('app/models', '', 'jwt_token.rb')
      template 'jwt_user.rb', File.join('app/models', '', 'jwt_user.rb')
    end
  end
end