# frozen_string_literal: true

require 'simple_schema_serializers/json_schema'
require 'simple_schema_serializers/serializable'
require 'json'

module SimpleSchemaSerializers
  # A +Serializable+ implementation that simply calls a single method
  # on the object to get it's serialized representation
  module PrimitiveMethodSerializer
    include Serializable

    # def serialize(resource, _options = {})
    #   resource.send(config[:method_name])
    # end

    def schema(additional_options = {})
      base_schema.merge(additional_options).transform_keys(&:to_s).slice(*allowed_keys).compact
    end
  end

  module DefaultSerializers
    # Serializer for string literals. Assumes resources reponds to to_s
    module StringSerializer
      include PrimitiveMethodSerializer
      extend self

      def serialize(resource, _options = {})
        resource.to_s
      end

      def base_schema
        { type: 'string' }
      end

      def allowed_keys
        JSONSchema::STRING_KEYS
      end
    end

    # Serializer for integers. Assumes resources reponds to to_i
    module IntegerSerializer
      include PrimitiveMethodSerializer
      extend self

      def serialize(resource, _options = {})
        resource.to_i
      end

      def base_schema
        { type: 'integer' }
      end

      def allowed_keys
        JSONSchema::NUMBER_KEYS
      end
    end

    # Serializer for floats. Assumes resources reponds to to_f
    module FloatSerializer
      include PrimitiveMethodSerializer
      extend self

      def serialize(resource, options = {})
        value = resource.to_f
        value = value.round(options[:round]) if options[:round]
        value
      end

      def base_schema
        { type: 'number', format: 'float' }
      end

      def allowed_keys
        JSONSchema::NUMBER_KEYS
      end
    end

    # Serializer for booleans. Converts truthy/falsey to true/false
    module BooleanSerializer
      include PrimitiveMethodSerializer
      extend self

      def serialize(resource, _options = {})
        !!resource
      end

      def base_schema
        { type: 'boolean' }
      end

      def allowed_keys
        JSONSchema::COMMON_KEYS
      end
    end

    # Serializer ISO 8601 date format, e.g. Date.today => "2020-01-24"
    module ISO8601DateSerializer
      include PrimitiveMethodSerializer
      extend self

      def serialize(resource, _options = {})
        resource.iso8601
      end

      def base_schema
        { type: 'string', format: 'date' }
      end

      def allowed_keys
        JSONSchema::STRING_KEYS
      end
    end

    # Serializer for ISO 8601 time format, e.g. DateTime.now, Time.now => "2020-01-24T20:13:39-05:00"
    module ISO8601DateTimeSerializer
      include PrimitiveMethodSerializer
      extend self

      def serialize(resource, options = {})
        return resource.iso8601(options[:fraction_digits] || 3) if resource.respond_to?(:iso8601)

        resource.strftime('%Y-%m-%dT%H:%M:%S.%L%z')
      end

      def base_schema
        { type: 'string', format: 'date-time' }
      end

      def allowed_keys
        JSONSchema::STRING_KEYS
      end
    end

    # Serializer for a hash with arbirary, undefined key-value pairs
    module ArbitraryHashSerializer
      include PrimitiveMethodSerializer
      extend self

      def serialize(resource, _options = {})
        as_json(resource.to_h)
      end

      # Simple, recursive as_json method (since we aren't necessarily
      # in a rails environment, we have to implement it ourselves).
      # Stringifies keys but leaves primitives as-is.
      def as_json(obj)
        case obj
        when Array
          obj.map { |v| as_json(v) }
        when Hash
          obj.to_h { |k, v| [k.to_s, as_json(v)] }
        else
          obj
        end
      end

      def base_schema
        {
          type: 'object',
          properties: {},
          required: [],
          additionalProperties: { type: 'string' }
        }
      end

      def allowed_keys
        JSONSchema::OBJECT_KEYS
      end
    end
  end
end
