# The main module for the has_remote plugin. Please see README for more information.
#
module HasRemote
  
  def self.included(base) #:nodoc:
    base.extend ClassMethods
  end
  
  # Returns an array of all models that have a remote.
  #
  def self.models
    # Make sure all models are loaded:
    Dir[File.join(RAILS_ROOT, 'app', 'models', '*.rb')].each { |f| require_dependency f }

    @models ||= []
  end
  
  # Updates cached attributes of all models that have a remote.
  # Also see HasRemote::Cache
  #
  def self.update_cached_attributes!
    models.each(&:update_cached_attributes!)
  end
      
  module ClassMethods
    
    # Gives your local ActiveRecord model a remote proxy (ActiveResource::Base),
    # which enables you to look for certain attributes remotely.
    # 
    # ==== Options
    # 
    # [:remote_key]  The name of the column used to store the id of the remote resource. Defaults to :remote_id.
    #
    # [:site, :user, :password, ...]  Basically all ActiveResource configuration settings are available,
    #                                 see http://api.rubyonrails.org/classes/ActiveResource/Base.html      
    # [:through]     Optional custom ActiveResource class name to use for the proxy. If not set, a default class called
    #                "<ModelName>::Remote" will be created dynamically. *Note* that any ActiveResource
    #                configuration options will still be applied to this class.
    #
    # ==== Usage
    #
    #  class User < ActiveRecord::Base
    #    has_remote :site => 'http://people.local'
    #  end
    #
    #  # In a migration:
    #  add_column :users, :remote_id, :integer
    #
    #  User.find(1).remote
    #  # => #<User::Remote> (inherits from ActiveResource::Base)
    #  User.find(1).remote.username
    #  # => "User name from remote server"
    #
    # has_remote also takes a block which is passed in a HasRemote::Config object which can be used to specify
    # remote attributes:
    #
    #  class User < ActiveRecord::Base
    #    has_remote :site => '...' do |remote|
    #      remote.attribute :username
    #      remote.attribute :full_name, :local_cache => true
    #      remote.attribute :email_address, :as => :email
    #    end 
    #  end
    #
    #  User.find(1).username
    #  # => "User name from remote server"
    #
    def has_remote(options, &block)
      unless self.const_defined?("Remote") # Never try this twice
        @remote_class = options[:through] ? options.delete(:through).constantize : self.const_set("Remote", ActiveResource::Base.clone)
      end
      
      @remote_key = options.delete(:remote_key) || :remote_id

      # create extra class methods
      class << self
        attr_reader :remote_class
        attr_reader :remote_key
        
        def remote_attributes # :nodoc:
          @remote_attributes ||= []
        end
        
        include HasRemote::Caching
      end
      
      # set ARes to look for correct resource (only if not manually specified)
      unless options[:element_name] || @remote_class.element_name != "remote"
        @remote_class.element_name = self.name.underscore.split('/').last
      end
      
      # setup ARes class with given options
      options.each do |option, value|
        @remote_class.send "#{option}=", value 
      end
      
      block.call( Config.new(self) ) if block_given?
      
      # make sure remote attributes are synced after every save
      after_save :update_cached_attributes!
      
      include InstanceMethods
      HasRemote.models << self
    end
    
  end
  
  module InstanceMethods
    
    # Returns the remote proxy for this record as an <tt>ActiveResource::Base</tt> object. 
    #
    # *Arguments*
    #
    # - <tt>force_reload</tt>:  Forces a reload from the remote server if set to true. Defaults to false.
    #
    def remote(force_reload = false)
      if force_reload || (@remote.nil? && has_remote?)
        @remote = self.class.remote_class.find(self.send(self.class.remote_key))
      end
      @remote
    end
    
    # Synchronizes all locally cached remote attributes.
    #
    # Note that when the remote does no longer exist, all remote attributes will be
    # set to nil.
    #
    def update_cached_attributes!
      unless self.class.cached_attributes.empty?
        self.class.cached_attributes.each do |remote_attr, local_attr|
          write_attribute(local_attr, remote(true).send(remote_attr))
        end
        update_without_callbacks if changed?
      end
    end
    
    # Checks whether a remote proxy exists.
    #
    def has_remote?
      # NOTE ARes#exists? is broken:
      # https://rails.lighthouseapp.com/projects/8994/tickets/1223-activeresource-head-request-sends-headers-with-a-nil-key
      #
      return !self.class.remote_class.find(self.send(self.class.remote_key)).nil? rescue false   
    end
  end
  
  class Config
    def initialize(base) #:nodoc:
      @base = base
    end
    
    # Defines a remote attribute. Adds a getter method on instances, which delegates to the remote object.
    #
    # *Options*
    #
    # [:local_cache]  If set to true the attribute will also be saved locally. See README for more information
    #                 about caching and synchronization.
    # [:as]           Optionally map remote attribute to this name.
    #
    # *Example*
    # 
    #  class User < ActiveRecord::Base
    #    has_remote :site => '...' do |remote|
    #      remote.attribute :name, :local_cache => true
    #      remote.attribute :email, :as => :email_address
    #    end
    #  end
    #
    def attribute(attr_name, options = {})
      method_name = options[:as] || attr_name
      @base.class_eval <<-RB
        def #{method_name}
          remote.nil? ? nil : remote.send(:#{attr_name})
        end
        def #{method_name}=(arg)
          raise NoMethodError.new("Remote attributes can't be set in this version of has_remote.")
        end
      RB
      @base.remote_attributes << attr_name
      @base.cached_attributes << [attr_name, method_name] if options[:local_cache]
    end
    
  end
  
end