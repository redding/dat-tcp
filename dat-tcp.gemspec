# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dat-tcp/version'

Gem::Specification.new do |gem|
  gem.name          = "dat-tcp"
  gem.version       = DatTCP::VERSION
  gem.authors       = ["Collin Redding", "Kelly Redding"]
  gem.email         = ["collin.redding@me.com", "kelly@kellyredding.com"]
  gem.description   = "DatTCP is a generic threaded TCP server implementation. It provides a " \
                      "simple to use interface for defining a TCP server. It is intended to be " \
                      "used as a base for application-level servers."
  gem.summary       = "DatTCP is a generic threaded TCP server for defining application-level " \
                      "servers."
  gem.homepage      = "https://github.com/redding/dat-tcp"

  gem.files         = `git ls-files -- lib/* Gemfile Rakefile *.gemspec`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency('assert',        ['~>0.8'])
  gem.add_development_dependency('assert-mocha',  ['~>0.1'])
end
