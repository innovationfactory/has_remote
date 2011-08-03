require 'rails'

module HasRemote
  class Railtie < Rails::Railtie
    initializer 'has_remote.load' do
      ActiveSupport.on_load(:active_record) do
        HasRemote::Railtie.load!
      end
    end

    rake_tasks do
      load 'tasks/has_remote.rake'
    end

    # generators do
    #   require 'generators/has_remote_migration_generator'
    # end

    def self.load!
      ActiveRecord::Base.send :include, HasRemote
      ActiveSupport.run_load_hooks(:has_remote)
    end
  end
end