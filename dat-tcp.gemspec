# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dat-tcp/version'

Gem::Specification.new do |gem|
  gem.name          = "dat-tcp"
  gem.version       = DatTCP::VERSION
  gem.authors       = ["Collin Redding", "Kelly Redding"]
  gem.email         = ["collin.redding@me.com", "kelly@kellyredding.com"]
  gem.description   = "A generic threaded TCP server API.  It is"\
                      " designed for use as a base for application servers."
  gem.summary       = "A generic threaded TCP server API"
  gem.homepage      = "https://github.com/redding/dat-tcp"

  gem.files         = `git ls-files -- lib/* Gemfile Rakefile *.gemspec`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency('assert',        ['~> 1.0'])
  gem.add_development_dependency('assert-mocha',  ['~> 1.0'])
end
