require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name        = "HasRemote"
    gem.version     = File.read('VERSION').chomp
    gem.summary     = "Bind a remote ActiveResource object to your local ActiveRecord objects."
    gem.description = "Bind a remote ActiveResource object to your local ActiveRecord objects, delegate attributes and optionally cache remote attributes locally."
    gem.email       = "sjoerd.andringa@innovationfactory.eu"
    gem.homepage    = "http://github.com/innovationfactory/has_remote"
    gem.authors     = ["Sjoerd Andringa"]
  end
  Jeweler::RubygemsDotOrgTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end
