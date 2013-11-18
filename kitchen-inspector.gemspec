# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen-inspector/inspector/version'

Gem::Specification.new do |spec|
  spec.name          = "kitchen-inspector"
  spec.version       = KitchenInspector::Inspector::VERSION
  spec.authors       = ["Stefano Tortarolo"]
  spec.email         = ["stefano.tortarolo@gmail.com"]
  spec.description   = %q{Given an Opscode Chef cookbook, verifies its dependencies against a Chef Server and a Gitlab instance}
  spec.summary       = %q{Kitchen integrity checker}
  spec.homepage      = "https://github.com/astratto/kitchen-inspector"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rubocop", "~> 0.14"
  spec.add_development_dependency "rake"

  spec.add_dependency "solve", "~> 0.8.0"
  spec.add_dependency "berkshelf", "~> 2.0.10"
  spec.add_dependency "thor", "~> 0.18.0"
  spec.add_dependency "terminal-table", "~> 1.4.5"
  spec.add_dependency "colorize", "~> 0.6.0"
  spec.add_dependency "gitlab"
  spec.add_dependency "chef", ">= 11.0.0"
end
