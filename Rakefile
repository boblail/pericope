$:.unshift File.expand_path("../lib", __FILE__)

require 'rubygems'
require 'pericope'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

task :install do 
  `gem build pericope.gemspec`
  `sudo gem install pericope-#{Pericope::VERSION}.gem`
end

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the pericope gem.'
Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
end

desc 'Generate documentation for the pericope plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Pericope'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end