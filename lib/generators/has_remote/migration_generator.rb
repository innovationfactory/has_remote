require 'rails/generators/active_record/migration'

module HasRemote
  module Generators
    class MigrationGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      extend  ActiveRecord::Generators::Migration

      source_root File.join(File.dirname(__FILE__), 'templates')

      desc <<-TXT.squish
        Creates a migration that will set up the has_remote_synchronizations table. You don't need this
        if you don't plan on synchronizing cached remote attributes.
      TXT
      def create_migration
        migration_template "create_has_remote_synchronizations.rb", "db/migrate/create_has_remote_synchronizations.rb"
      end
    end
  end
end