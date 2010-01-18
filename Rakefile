require 'rubygems'
require 'rake'
require 'rake/rdoctask'
require 'spec/rake/spectask'

desc 'Generate documentation for the has_remote plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = 'HasRemote'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.exclude('lib/generators')
end

desc "Run all RSpec examples"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.spec_opts = %w(-cfs)
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name        = "HasRemote"
    gemspec.summary     = "Bind a remote ActiveResource object to your local ActiveRecord objects."
    gemspec.description = "Bind a remote ActiveResource object to your local ActiveRecord objects, delegate attributes and optionally cache remote attributes locally."
    gemspec.email       = "sjoerd.andringa@innovationfactory.eu"
    gemspec.homepage    = "http://github.com/innovationfactory/has_remote"
    gemspec.authors     = ["Sjoerd Andringa"]
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end
