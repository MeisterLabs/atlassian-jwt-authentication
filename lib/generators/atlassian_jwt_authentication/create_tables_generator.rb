require 'rails/generators/active_record'

module AtlassianJwtAuthentication
  class CreateTablesGenerator < Rails::Generators::Base
    include Rails::Generators::Migration
    desc 'Create a migration to add atlassian jwt specific fields to your model.'

    def self.source_root
      @source_root ||= File.expand_path('../templates', __FILE__)
    end

    def self.next_migration_number(dirname)
      next_migration_number = current_migration_number(dirname) + 1
      ActiveRecord::Migration.next_migration_number(next_migration_number)
    end

    def self.current_migration_number(dirname) #:nodoc:
      migration_lookup_at(dirname).collect do |file|
        File.basename(file).split("_").first.to_i
      end.max.to_i
    end

    def self.migration_lookup_at(dirname) #:nodoc:
      Dir.glob("#{dirname}/[0-9]*_*.rb")
    end

    def generate_migration
      migration_template 'jwt_tokens_migration.rb.erb', "db/migrate/#{migration_file_name}"
    end

    def migration_name
      'create_atlassian_jwt_tokens'
    end

    def migration_file_name
      "#{migration_name}.rb"
    end

    def migration_class_name
      migration_name.camelize
    end
  end
end