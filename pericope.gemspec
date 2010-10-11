# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
require 'pericope/version'
  
Gem::Specification.new do |s|
  s.name         = "pericope"
  s.version      = Pericope::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = ["Bob Lail"]
  s.email        = ["robert.lail@cph.org"]
  # s.homepage     = "http://cphepdev.cph.pri"
  s.summary      = "Parses Bible references"
  # s.description  = "Epic automates administrative tasks for Emerging Products"
                   
  s.required_rubygems_version = ">= 1.3.6"
  s.add_dependency "activesupport"
                           
  s.files        = Dir.glob("{data,lib}/**/*") + %w(README.mdown)
  s.executables  = []
  # s.default_executable = 'epic'
  s.require_path = 'lib'
end
