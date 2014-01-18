# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bit_analytics/version'

Gem::Specification.new do |spec|
  spec.name          = "bit_analytics"
  spec.version       = BitAnalytics::VERSION
  spec.authors       = ["Jure Triglav"]
  spec.email         = ["juretriglav@gmail.com"]
  spec.description   = %q{Analytics library built with Redis bitmaps}
  spec.summary       = %q{Implements a powerful analytics library on top of Redis's support for bitmaps and bitmap operations.}
  spec.homepage      = "http://www.github.com/jure/bit_analytics"
  spec.license       = "BSD"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "redis", "~> 3.0"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "pry"
end
