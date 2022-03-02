# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'simple_schema_serializers/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'simple_schema_serializers'
  spec.version     = SimpleSchemaSerializers::VERSION
  spec.authors     = ['Charles Julian Knight']
  spec.email       = ['julian@fixdapp.com']
  spec.homepage    = 'https://github.com/fixdauto/simple_schema_serializers'
  spec.summary     = 'Fast model serializers with json-schema generation'
  spec.licenses    = ['MIT']
  spec.required_ruby_version = '>= 2.6'

  spec.files = Dir['lib/**/*', 'Rakefile', 'README.md']

  spec.add_dependency 'json-schema', '~> 2.8.0'

  spec.metadata['allowed_push_host'] = 'http://rubygems.org'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
