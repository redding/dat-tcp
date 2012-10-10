# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'threaded_server/version'

Gem::Specification.new do |gem|
  gem.name          = "threaded_server"
  gem.version       = ThreadedServer::VERSION
  gem.authors       = ["Collin Redding"]
  gem.email         = ["collin.redding@me.com"]
  gem.description   = "TODO"
  gem.summary       = "TODO"
  gem.homepage      = ""

  gem.files         = `git ls-files -- lib/* Gemfile Rakefile *.gemspec`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
