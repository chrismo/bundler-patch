# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bundler/patch/version'

Gem::Specification.new do |spec|
  spec.name          = 'bundler-patch'
  spec.version       = Bundler::Patch::VERSION
  spec.authors       = ['chrismo']
  spec.email         = ['chrismo@clabs.org']

  spec.summary       = %q{Conservative bundler updates}
  # spec.description   = ''
  spec.homepage      = 'https://github.com/livingsocial/bundler-patch'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = ['bundler-patch']
  spec.require_paths = ['lib']

  spec.add_dependency 'bundler-advise', '~> 1.0', '>= 1.0.3'
  spec.add_dependency 'slop', '~> 4.0'
  spec.add_dependency 'bundler', '~> 1.10.0' # TODO: does not work with 1.11.x yet

  spec.add_development_dependency 'bundler-fixture', '~> 1.3'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'
end
