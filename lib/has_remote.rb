require 'has_remote/synchronizable'
require 'has_remote/synchronization'
require 'has_remote/railtie'

# The main module for the has_remote plugin. Please see {file:README.rdoc README} for more information.
#
module HasRemote

  def self.included(base)
    base.extend ClassMethods
  end

  # Returns an array of all models that have a remote.
  #
  def self.models
    # Make sure all models are loaded:
    if Rails.root
      Dir[Rails.root.join('app', 'models', '*.rb')].each { |f| require_dependency f }
    end

    @models ||= []
  end

  # Updates cached attributes, destroys deleted records and adds new records of all models that have a remote.
  # Also see {HasRemote::Synchronizable}.
  #
  def self.synchronize!
    models.each(&:synchronize!)
  end

  module ClassMethods

    # Binds your <tt>ActiveRecord</tt> objects to a remote <tt>ActiveResource</tt> resource,
    # and enables you to look for certain attributes remotely.
    #
    # ==== Usage:
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
    # has_remote also takes a block which is passed in a {Config} object which can be used to specify
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
    # @option options [Symbol, String] :foreign_key (:remote_id) The name of the column used to store the id of the remote resource..
    # @option options [Symbol, String] :remote_primary_key (:id) The name of the remote resource's primary key.
    # @option options [String] :through Optional custom <tt>ActiveResource</tt> class name to use for the proxy. If not set, a default class called
    #                          <tt>Remote</tt> will be created dynamically, namespaced inside the current model. *Note* that any <tt>ActiveResource</tt>
    #                          configuration options will still be applied to this class.
    # @option options Other All other options you pass in will be used to configure the <tt>ActiveResource</tt> model, you can use any setting for {http://api.rubyonrails.org/classes/ActiveResource/Base.html ActiveResource::Base}, such as <tt>:site</tt>, <tt>:user</tt> and <tt>:password</tt>.
    # @yieldparam [Config] remote Configure attributes to be delegated or a custom finder.
    #
    def has_remote(options, &block)
      unless options[:through] || self.const_defined?("Remote")
        self.const_set("Remote", Class.new(ActiveResource::Base))
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

        include HasRemote::Synchronizable
      end

      # set ARes to look for correct resource (only if not manually specified)
      unless options[:element_name] || @remote_class.element_name != "remote"
        @remote_class.element_name = self.name.underscore.split('/').last
      end

      # setup ARes class with given options
      options.each do |option, value|
        @remote_class.send "#{option}=", value
      end

      attr_accessor :skip_update_cache

      block.call( Config.new(self) ) if block_given?

      include InstanceMethods
      HasRemote.models << self
    end

  end

  module InstanceMethods

    # Returns the remote proxy for this record as an <tt>ActiveResource::Base</tt> object. Returns <tt>nil</tt>
    # if foreign key is <tt>nil</tt>.
    #
    # @param [Boolean] force_reload Forces a reload from the remote server if set to <tt>true</tt>.
    #
    def remote(force_reload = false)
      if force_reload || @remote.nil?
        id = self.send(self.class.remote_foreign_key)
        @remote = id ? (self.class.remote_finder ? self.class.remote_finder[id] : self.class.remote_class.find(id)) : nil
      end
      @remote
    end

    # Checks whether a remote proxy exists.
    #
    # @return [Boolean]
    #
    def has_remote?
      # NOTE ARes#exists? is broken:
      # https://rails.lighthouseapp.com/projects/8994/tickets/1223-activeresource-head-request-sends-headers-with-a-nil-key
      #
      return !remote(true).nil? rescue false
    end

    # Synchronizes all locally cached remote attributes to this object and saves the object.
    #
    # @raise [ActiveRecord::RecordInvalid]
    #
    def update_cached_attributes!
      update_cached_attributes
      save!
    end

    # Synchronizes all locally cached remote attributes to this object, but does not save the object.
    #
    # Note that when the remote does no longer exist, all remote attributes will be
    # set to <tt>nil</tt>.
    #
    def update_cached_attributes
      unless self.skip_update_cache || self.class.cached_attributes.empty?
        r = has_remote? ? remote : nil
        self.class.cached_attributes.each do |remote_attr|
          local_attr = self.class.remote_attribute_aliases[remote_attr] || remote_attr
          write_attribute(local_attr, r.try(remote_attr))
        end
      end
    end

  end

  # The block argument for {HasRemote::ClassMethods#has_remote} is an instance of this class.
  # It can be used to configure HasRemote's behaviour for a model.
  #
  class Config

    # @private
    def initialize(base) #:nodoc:
      @base = base
    end

    # Defines a remote attribute. Adds a getter method on instances, which delegates to the remote object.
    #
    # ==== Example:
    #
    #  class User < ActiveRecord::Base
    #    has_remote :site => '...' do |remote|
    #      remote.attribute :name, :local_cache => true
    #      remote.attribute :email, :as => :email_address
    #    end
    #  end
    #
    # @param [String, Symbol] attr_name The name of the attribute you want to delegate to the remote.
    # @option options [Boolean] :local_cache (false) If set to <tt>true</tt> the attribute will also be saved locally. See {file:README.rdoc README} for more information
    #                 about caching and synchronization.
    # @option options [Symbol, String] :as Optionally map the remote attribute to this name.
    #
    def attribute(attr_name, options = {})
      method_name = options[:as] || attr_name

      @base.remote_attributes << attr_name
      @base.remote_attribute_aliases = @base.remote_attribute_aliases.merge(attr_name => method_name)

      unless options[:local_cache]
        @base.class_eval <<-RB

          def #{method_name}
            remote.try(:#{attr_name})
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
    # It takes a block which is passed in the ID of the remote object.
    #
    # By default the following finder is used:
    #  MyModel.remote_class.find(id)
    #
    # ==== Example:
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