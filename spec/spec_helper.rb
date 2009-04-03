require 'rubygems'
require 'active_record'
require 'active_resource'

RAILS_ROOT = File.dirname(__FILE__)

require File.dirname(__FILE__) + '/../lib/has_remote'
require File.dirname(__FILE__) + '/../lib/has_remote/cache'
require File.dirname(__FILE__) + '/../lib/has_remote/synchronization'

require "#{File.dirname(__FILE__)}/../init"

config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config['test'])

load(File.dirname(__FILE__) + "/schema.rb") if File.exist?(File.dirname(__FILE__) + "/schema.rb")
 
require File.dirname(__FILE__) + '/has_remote_spec/user'
require File.dirname(__FILE__) + '/has_remote_spec/book'
 
User = HasRemoteSpec::User
Book = HasRemoteSpec::Book