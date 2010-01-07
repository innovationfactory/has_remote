# Fake Rails constants
RAILS_ENV  = ENV["RAILS_ENV"] ||= 'test'
RAILS_ROOT = File.dirname(__FILE__)

# Include required libraries
require 'rubygems'
require 'active_record'
require 'active_resource'
require 'shoulda/active_record/matchers'
include Shoulda::ActiveRecord::Matchers

# Include plugin's files
require File.dirname(__FILE__) + '/../lib/has_remote'
require File.dirname(__FILE__) + '/../lib/has_remote/synchronizable'
require File.dirname(__FILE__) + '/../lib/has_remote/synchronization'

# Initialize plugin
require "#{File.dirname(__FILE__)}/../init"

# Create logger
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")

# Setup database connection and structure
config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.establish_connection(config[ENV['RAILS_ENV']])
load(File.dirname(__FILE__) + "/schema.rb")

# Require models
require File.dirname(__FILE__) + '/has_remote_spec/user'
require File.dirname(__FILE__) + '/has_remote_spec/book'
require File.dirname(__FILE__) + '/has_remote_spec/product'
require File.dirname(__FILE__) + '/has_remote_spec/cheese'

# Create schortcuts 
User = HasRemoteSpec::User
Book = HasRemoteSpec::Book
Product = HasRemoteSpec::Product
Cheese  = HasRemoteSpec::Cheese