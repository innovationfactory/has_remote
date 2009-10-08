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
    # [:foreign_key]  The name of the column used to store the id of the remote resource. Defaults to :remote_id.
    # [:remote_primary_key]  The name of the remote resource's primary key. Defaults to :id.
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
      unless options[:through] || self.const_defined?("Remote")
        self.const_set("Remote", ActiveResource::Base.clone)
      end
      
      @remote_class = options[:through] ? options.delete(:through).constantize : self::Remote
      
      @remote_foreign_key = options.delete(:foreign_key) || :remote_id
      
      @remote_primary_key = options.delete(:remote_primary_key) || :id
      
      # create extra class methods
      class << self
        attr_reader :remote_class
        attr_reader :remote_foreign_key
        attr_reader :remote_finder
        attr_reader :remote_primary_key
        attr_writer :remote_attribute_aliases
        
        def remote_attributes # :nodoc:
          @remote_attributes ||= []
        end
        
        def remote_attribute_aliases # :nodoc:
          @remote_attribute_aliases ||= {}
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
      
      # After save callback in order to update cached attributes will be omitted when set to true
      attr_accessor :skip_update_cache
      
      # make sure remote attributes are synced after every save
      after_save :update_cached_attributes!, :unless => lambda { |record| record.skip_update_cache }
      
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
      if force_reload || @remote.nil?
        id = self.send(self.class.remote_foreign_key)
        @remote = (self.class.remote_finder ? self.class.remote_finder[id] : self.class.remote_class.find(id)) rescue nil
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
        self.class.cached_attributes.each do |remote_attr|
          local_attr = self.class.remote_attribute_aliases[remote_attr] || remote_attr
          write_attribute(local_attr, has_remote? ? remote(true).send(remote_attr) : nil)
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
      return !remote(true).nil? rescue false   
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
      
      @base.remote_attributes << attr_name
      @base.remote_attribute_aliases = @base.remote_attribute_aliases.merge(attr_name => method_name)
      
      unless options[:local_cache]
        @base.class_eval <<-RB

          def #{method_name}
            remote.nil? ? nil : remote.send(:#{attr_name})
          end

          def #{method_name}=(arg)
            raise NoMethodError.new("Remote attributes can't be set directly in this version of has_remote.")
          end

        RB
      else
        @base.cached_attributes << attr_name
      end
      
    end
    
    # Lets you specify custom finder logic to find the record's remote object.
    # It takes a block which is passed in the id of the remote object.
    #
    # (By default <tt>Model.remote_class.find(id)</tt> would be called.)
    #
    # *Example*
    #
    #  class User < ActiveRecord::Base
    #    has_remote :site => "..." do |remote|
    #      remote.finder do |id|
    #        User::Remote.find :one, :from => "users/active/#{id}.xml"
    #      end
    #    end
    #  end
    #
    def finder(&block)
      @base.instance_variable_set "@remote_finder", block
    end
    
  end
  
end