# frozen_string_literal: true

require 'simple_schema_serializers/declaration_error'

module SimpleSchemaSerializers
  # A container class for a single property of a +HashSerializable+.
  class Attribute
    attr_reader :name, :serializer, :source

    def initialize(name, serializer, options)
      @name = name.to_s
      @serializer = serializer
      @options = options
      @source = @options.delete(:source) || name
      @conditional = @options.delete(:if)
      @key_transform = @options.delete(:key_transform)
      @required = @options.key?(:required) ? @options.delete(:required) : !(hidden? || conditional?)
    end

    def key(serializer_instance)
      return name unless @key_transform
      return @key_transform.call(name) if @key_transform.respond_to?(:call)
      if maybe_private_method?(serializer_instance, @key_transform, all_methods: true)
        return serializer_instance.send(@key_transform, name)
      end

      name.public_send(@key_transform)
    end

    def skip?(serializer_instance)
      return false unless conditional?

      !check_condition(serializer_instance)
    end

    def hidden?
      @options[:hidden]
    end

    def serialize(serializer_instance)
      value = value_from(serializer_instance) || default_value
      serializer.serialize(value, **@options.merge(serializer_instance.options))
    end

    def required?
      @required
    end

    def schema(**additional_options)
      serializer.schema(**@options.transform_keys(&:to_s).merge(additional_options))
    end

    private

    def value_from(serializer_instance)
      if serializer_instance.object.is_a?(Hash)
        value_from_hash(serializer_instance)
      elsif maybe_private_method?(serializer_instance, source)
        serializer_instance.send(source)
      elsif serializer_instance.object.respond_to?(source, false)
        serializer_instance.object.public_send(source)
      else
        raise DeclarationError, "Unknown method or key `#{source}` for attribute " \
                                "`#{name}` of `#{serializer_instance.class.name}`"
      end
    rescue ArgumentError => e
      raise ArgumentError, "Problem accessing `#{source}` on #{serializer_instance.object} in " \
                           "#{serializer_instance.class.name}: #{e.message}"
    end

    def value_from_hash(serializer_instance)
      if maybe_private_method?(serializer_instance, source)
        serializer_instance.send(source)
      elsif serializer_instance.object.key?(source)
        serializer_instance.object[source]
      elsif serializer_instance.object.key?(source.to_s)
        serializer_instance.object[source.to_s]
      else
        return nil if @options[:allow_missing_key]

        raise DeclarationError, "Key `#{source}` missing from hash instance `#{name}`" \
                                "in `#{serializer_instance.class.name}`. If this is intentional, specify " \
                                'option `allow_missing_key: true`'
      end
    end

    def default_value
      @options[:default]
    end

    def conditional?
      @conditional
    end

    def check_condition(serializer_instance)
      if @conditional.respond_to?(:call)
        serializer_instance.instance_exec(&@conditional)
      elsif maybe_private_method?(serializer_instance, @conditional)
        serializer_instance.send(@conditional)
      else
        serializer_instance.object.public_send(@conditional)
      end
    end

    def maybe_private_method?(serializer_instance, source, all_methods: false)
      serializer_instance.public_methods(all_methods).include?(source) ||
        serializer_instance.protected_methods(all_methods).include?(source) ||
        serializer_instance.private_methods(all_methods).include?(source)
    end
  end
end
