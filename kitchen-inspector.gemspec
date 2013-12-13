# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen-inspector/inspector/version'

# Generate pre-release versions for non tagged releases
git_version = begin
  describe = `git describe`
  if $?.success?
    stripped = describe.strip
    /^([^-]+)-([0-9]+)-[^-]+$/.match(stripped) ? "#{$1}.#{$2}" : stripped
  else
    git_raw = `git log --pretty=format:%h | head -n1`
    $?.success? ? '0.0.0.%d' % git_raw.strip.to_i(16) : '0.0.0'
  end
end

Gem::Specification.new do |spec|
  spec.name          = "kitchen-inspector"
  spec.version       = git_version
  spec.authors       = ["Stefano Tortarolo"]
  spec.email         = ["stefano.tortarolo@gmail.com"]
  spec.description   = %q{Given an Opscode Chef cookbook, verifies its dependencies against a Chef Server and a Repository Manager instance (i.e., Gitlab)}
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
  spec.add_development_dependency 'chef-zero'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'coveralls'

  spec.add_dependency "solve", "~> 0.8.0"
  spec.add_dependency "berkshelf", "~> 2.0.10"
  spec.add_dependency "thor", "~> 0.18.0"
  spec.add_dependency "terminal-table", "~> 1.4.5"
  spec.add_dependency "colorize", "~> 0.6.0"
  spec.add_dependency "gitlab"
  spec.add_dependency "chef", ">= 11.0.0"
  spec.add_dependency "octokit", "~> 2.0"
  spec.add_dependency "googl", "~> 0.6.3"
end
