# frozen_string_literal: true

require 'simple_schema_serializers/declaration_error'
require 'simple_schema_serializers/json_schema'
require 'simple_schema_serializers/attribute'

module SimpleSchemaSerializers
  ##
  # This is the base interface for any serializer. You can include this mixin for writing your own
  # attribute serializers.
  #
  # In addition to the methods below, every serializable should implement two methods:
  # [+serialize(resource, scope = {})+]   given a resource and a scope, return the serialized representation
  # [+schema+]                            the json-schema definition of the serialized representation
  module Serializable
    include JSONSchema::Validatable

    def self.included(base)
      base.prepend(SanitizeSchema)
    end

    def self.extended(base)
      base.singleton_class.prepend(SanitizeSchema)
    end

    # ensure the schema method always returns string keys
    module SanitizeSchema
      def schema(...)
        super.transform_keys(&:to_s)
      end
    end

    ##
    # convert the +resource+ (target object) and +scope+ (optional hash of arbitrary data) into
    # a serialized representation.
    def serialize(_resource, **)
      raise DeclarationError, "The `serialize` method on #{inspect} has not been defined"
    end

    ##
    # Return the json-schema definition of the serialized representation.
    # This site can be very helpful in understanding the json-schema standard:
    #   https://json-schema.org/understanding-json-schema/index.html
    def schema(**)
      raise DeclarationError, "The `schema` method on #{inspect} has not been defined"
    end

    ##
    # Takes the same arguments as +serialize+, but passing an array or resources to be serialized
    # instead of a single resource. Returns an array of serialized resources.
    def serialize_list(*args)
      array.serialize(*args)
    end

    ##
    # Get an optional version of this serializer. Here, optional means the serialized value will be
    # `nil` if the resource is `nil`.
    def optional
      OptionalSerializer.new(self)
    end

    ##
    # Get a version of this serializer that can handle an array of resources instead of a single resource.
    # +schema_args+ are added to the json-schema definition.
    def array(**schema_args)
      ArraySerializer.new(self, schema_args)
    end

    def with_options(**default_options)
      ScopedSerializer.new(self, default_options)
    end

    def ref_name
      nil
    end

    def ref_path
      "#/definitions/#{ref_name}" if ref_name
    end

    def reference_schema
      { '$ref' => ref_path } if ref_name
    end
  end
end
require 'simple_schema_serializers/array_serializer'
require 'simple_schema_serializers/optional_serializer'
require 'simple_schema_serializers/scoped_serializer'
