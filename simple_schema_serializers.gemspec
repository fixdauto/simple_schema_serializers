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
  spec.homepage    = 'https://git.fixdapp.com'
  spec.summary     = 'Fast model serializers with json-schema generation'
  spec.licenses    = ['Nonstandard'] # Currently closed-source, may open in future
  spec.required_ruby_version = '>= 2.6.6'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata['allowed_push_host'] = 'DISABLED' if spec.respond_to?(:metadata)

  spec.files = Dir['{app,config,lib}/**/*', 'Rakefile', 'README.md']

  spec.add_dependency 'json-schema', '~> 2.8.0'
end
