# frozen_string_literal: true

module SimpleSchemaSerializers
  # Generate the json schema for the given hash serializer
  class HashSchemaGenerator
    attr_reader :hash_serializer, :additional_options

    def initialize(hash_serializer, additional_options)
      @hash_serializer = hash_serializer
      @additional_options = additional_options
      @use_refs = additional_options.delete(:use_refs) if additional_options.key?(:use_refs)
    end

    def schema
      return ref_schema if @use_refs && hash_serializer.ref_path

      unsanitized_schema.transform_keys(&:to_s).slice(*JSONSchema::OBJECT_KEYS).compact
    end

    private

    def ref_schema
      { '$ref' => hash_serializer.ref_path }.merge(additional_options)
    end

    def unsanitized_schema
      base_schema.merge(hash_serializer.schema_options).merge(additional_options)
    end

    def base_schema
      {
        'required' => required_keys,
        'type' => 'object',
        'properties' => property_schemas
      }
    end

    def required_keys
      hash_serializer.attributes.select(&:required?).map(&:name)
    end

    def property_schemas
      hash_serializer.attributes.each_with_object({}) do |attribute, property_schemas|
        next if attribute.hidden?

        property_schemas[attribute.name.to_s] = attribute.schema(use_refs: @use_refs != false)
      end
    end
  end
end
