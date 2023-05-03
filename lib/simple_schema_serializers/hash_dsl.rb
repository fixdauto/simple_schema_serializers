# frozen_string_literal: true

require 'simple_schema_serializers/declaration_error'

module SimpleSchemaSerializers
  # methods for the block scope of `hash_attribute` method
  module HashDSL
    def object_description(desc)
      schema_options['description'] = desc.chomp
    end

    def defines(name)
      @name = name.to_s
    end

    ##
    # Provide a string description of the attribute to be defined
    def desc(description)
      @desc = description.chomp
    end

    ##
    # Define an attribute.
    # [+name+]         the key in the output, typically the method name on the object
    # [+serializer+]   a +Serializable+ instance (or alias of one) to use for this attribute
    # [+opts.source+]  use a method on the serializer or object that is different than the output name
    # [+opts.if+]      conditonally add the attribute to the output. A proc/lambda or a method name on the object
    # [+opts.default+] if `nil`, return the serialized representation of this value instead
    # in addition, any json-schema keys in +opts+ will be included in the json-schema, e.g. `format`, `enum`, etc.
    def attribute(name, serializer, **opts)
      serializer_defaults = serializer_option_defaults(serializer)
      opts = attribute_defaults.merge(serializer_defaults).merge({ description: @desc }.compact).merge(opts)
      @desc = nil # clear the description out so it doesn't get written to all subsequent attributes
      attributes << Attribute.new(name, lookup_serializer(serializer), opts)
    end

    def hash_attribute(name, **opts, &)
      serializer = Class.new(HashSerializer)
      serializer.inherit_configuration_from(self, include_attributes: false)
      serializer.instance_exec(&)
      serializer = serializer.optional if opts.delete(:optional)
      attribute(name, serializer, **opts)
    end

    def array_attribute(name, **opts, &)
      desc = @desc
      @desc = nil
      serializer, item_opts = ArrayDSL.new(self).invoke(&)
      optional = opts.delete(:optional)
      array_opts, attribute_opts = opts.partition do |k, _|
        [*JSONSchema::ARRAY_KEYS, *JSONSchema::COMMON_KEYS].include?(k.to_s)
      end.map(&:to_h)
      serializer = lookup_serializer(serializer).array(**{ description: desc }.compact.merge(array_opts))
      serializer = serializer.optional if optional
      # TODO: probably not the best to just merge these together. Fundementally there needs to be a clearer
      # separation of which options go where
      attribute(name, serializer, **item_opts.merge(attribute_opts))
    end

    def remove_attribute(name)
      attribute = attributes.find { |a| a.name == name.to_s }
      raise DeclarationError, "Cannot remove undefined attribute #{name}" unless attribute

      attributes.delete(attribute)
      attributes
    end

    private

    def serializer_option_defaults(alias_name)
      return {} if alias_name.respond_to?(:serialize)

      _, opts = registered_serializers[alias_name.to_s]
      opts || {}
    end
  end
end
