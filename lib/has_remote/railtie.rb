require 'rails'

module HasRemote
  # @private
  class Railtie < Rails::Railtie  #:nodoc:
    initializer 'has_remote.load' do
      ActiveSupport.on_load(:active_record) do
        HasRemote::Railtie.load!
      end
    end

    rake_tasks do
      load 'tasks/has_remote.rake'
    end

    def self.load!
      ActiveRecord::Base.send :include, HasRemote
      ActiveSupport.run_load_hooks(:has_remote)
    end
  end
end