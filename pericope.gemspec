# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
require 'pericope/version'
  
Gem::Specification.new do |s|
  s.name         = "pericope"
  s.version      = Pericope::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = ["Bob Lail"]
  s.email        = ["bob.lailfamily@gmail.com"]
  s.homepage     = "http://github.com/boblail/Pericope"
  s.summary      = "Parses Bible references"
  # s.description  = "Epic automates administrative tasks for Emerging Products"
                   
  s.required_rubygems_version = ">= 1.3.6"
  s.add_dependency "activesupport"
  s.add_development_dependency "turn"
  s.add_development_dependency "pry"
                           
  s.files        = Dir.glob("{bin,data,lib}/**/*") + %w(README.mdown)
  s.executables  = ['pericope']
  s.default_executable = 'pericope'
  s.require_path = 'lib'
end
