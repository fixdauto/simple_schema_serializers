# frozen_string_literal: true

require 'json-schema'

module SimpleSchemaSerializers
  module JSONSchema
    COMMON_KEYS = %w[description type format example examples default enum].freeze
    STRING_KEYS = (COMMON_KEYS + %w[minLength maxLength pattern]).freeze
    NUMBER_KEYS = (COMMON_KEYS + %w[multipleOf minimum exclusiveMinimum maximum exclusiveMaximum]).freeze
    ARRAY_KEYS = %w[type items minItems maxItems uniqueItems].freeze
    OBJECT_KEYS = (COMMON_KEYS + %w[
      properties required $ref additionalProperties propertyNames
      minProperties maxProperties dependencies patternProperties
    ]).freeze

    # Something with a json schema that can be used to validate object schemas
    module Validatable
      ##
      # If there are options you wish to pass +JSON::Validator+ when validating.
      # See: https://github.com/ruby-json-schema/json-schema/tree/master#advanced-options
      def validation_options(args = nil)
        unless @validation_options
          @validation_options = {}
          if respond_to?(:superclass) && superclass.respond_to?(:validation_options)
            @validation_options.merge!(superclass.validation_options)
          end
        end
        @validation_options.merge!(args) if args
        @validation_options
      end

      ##
      # Check that +target+ matches +schema+, or raise +JSON::Schema::ValidationError+.
      def validate!(target)
        JSON::Validator.validate!(schema, target, validation_options)
      end

      ##
      # Check if +target+ matches +schema+
      def valid?(target)
        JSON::Validator.validate(schema, target, validation_options)
      end
    end
  end
end
