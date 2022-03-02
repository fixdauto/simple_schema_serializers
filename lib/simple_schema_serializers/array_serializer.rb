# frozen_string_literal: true

require 'simple_schema_serializers/serializable'

module SimpleSchemaSerializers
  ##
  # A wrapper serializer for returning a collection of items serialized by +delegate+.
  #
  # You can get an instance of this by calling +array+ on any other +Serializable+.
  class ArraySerializer
    include Serializable

    def initialize(delegate, array_opts = {})
      @delegate = delegate
      @array_opts = array_opts
    end

    def serialize(resources, options = {})
      resources.map { |resource| @delegate.serialize(resource, options) }
    end

    def schema(additional_options = {})
      element_schema = @delegate.schema(additional_options)
      unsanitized_schema = @array_opts.merge(type: 'array', items: element_schema)
      unsanitized_schema.transform_keys(&:to_s).slice(*JSONSchema::ARRAY_KEYS, *JSONSchema::COMMON_KEYS).compact
    end

    def inspect
      "#{self.class.name}<#{@delegate.inspect}>"
    end
  end
end
