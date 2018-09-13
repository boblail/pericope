# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require "pericope/version"

Gem::Specification.new do |s|
  s.name         = "pericope"
  s.version      = Pericope::VERSION
  s.platform     = Gem::Platform::RUBY
  s.authors      = ["Bob Lail"]
  s.email        = ["bob.lailfamily@gmail.com"]
  s.homepage     = "http://github.com/boblail/pericope"
  s.summary      = "Pericope is a gem for parsing Bible references."
  s.description  = "It recognizes common abbreviations and misspellings for names of the books of the Bible and a variety of ways of denoting ranges of chapters and verses. It can parse pericopes singly or out of a block of text. It's useful for comparing two pericopes for intersection and normalizing them into a well-formatted string."

  s.files        = Dir.glob("{bin,data,lib}/**/*") + %w(README.mdown)
  s.executables  = ["pericope"]
  s.default_executable = "pericope"
  s.require_path = "lib"

  s.add_development_dependency "bundler", "~> 1.10"
  s.add_development_dependency "rake", "~> 10.0"
  s.add_development_dependency "shoulda-context"
  s.add_development_dependency "pry"
  s.add_development_dependency "minitest", "~> 5.0"
  s.add_development_dependency "minitest-reporters"
  s.add_development_dependency "minitest-reporters-turn_reporter"
end
