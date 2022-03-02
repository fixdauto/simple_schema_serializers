# frozen_string_literal: true

require 'simple_schema_serializers/serializable'

module SimpleSchemaSerializers
  ##
  # A wrapper serializer for allowing a property to be +nil+.
  #
  # You can get an instance of this by calling +optional+ on any other +Serializable+.
  # The convention for serializer aliases is that optional forms end in `?`, e.g. `:string?`.
  class OptionalSerializer
    include Serializable

    def initialize(delegate)
      @delegate = delegate
    end

    def serialize(resource, options = {})
      return nil if resource.nil?

      @delegate.serialize(resource, options)
    end

    def schema(additional_options = {})
      parent_schema = @delegate.schema(additional_options)
      return { 'oneOf' => [{ 'type' => 'null' }, parent_schema] } if non_primitive?

      parent_schema['type'] = delegate_types + ['null']
      parent_schema['enum'] << nil if parent_schema['enum'] && !parent_schema['enum'].include?(nil)
      parent_schema
    end

    def inspect
      "#{self.class.name}<#{@delegate.inspect}>"
    end

    private

    def non_primitive?
      @delegate.schema['$ref'] || delegate_types.include?('object') || delegate_types.include?('array')
    end

    def delegate_types
      t = @delegate.schema['type']
      tt = t.is_a?(Array) ? t : [t]
      tt.map(&:to_s)
    end
  end
end
