# frozen_string_literal: true

require 'case_transform'
require 'simple_schema_serializers/declaration_error'
require 'simple_schema_serializers/serializable'
require 'simple_schema_serializers/hash_schema_generator'
require 'simple_schema_serializers/hash_dsl'
require 'simple_schema_serializers/array_dsl'
require 'simple_schema_serializers/combo_dsl'

module SimpleSchemaSerializers
  ##
  # A base class for defining serializers of type `object` (i.e. hashes).
  #
  # In addition to the +Serializer+ functionality, it supplies the
  # attribute DSL for declaring the properties of the serialized object,
  # and provides implementations for +serialize+ and +schema+.
  #
  # You are likely better off inheriting from +Serializer+, but if you
  # wish to extend an existing class with serialization functionality
  # you can include this mixin instead. Doing so will not register any
  # serializer aliases by default, so you will need to explicitly register
  # any you wish to use.
  class HashSerializer
    # The DSL methods for declaring a HashSerializable
    module ClassMethods
      include Serializable
      include HashDSL

      def registered_serializers
        @registered_serializers ||= {}
      end

      def attributes
        @attributes ||= []
      end

      def attribute_defaults(args = nil)
        @attribute_defaults ||= {}
        @attribute_defaults[:key_transform] = key_transformer if key_transformer
        @attribute_defaults.merge!(args) if args
        @attribute_defaults
      end

      def schema_options(args = nil)
        @schema_options ||= {}
        @schema_options.merge!(args) if args
        @schema_options
      end

      def inherit_configuration_from(other_hash_serializable, include_attributes: false)
        # class inheritance should get everything. Anonymous instances, e.g. has_serializable
        # and array_serializable are trickier.
        # TODO: it defintely shouldn't inherit attributes. it probably shouldn't
        # inherit attribute_defaults? should it inherit schema_options?
        registered_serializers.merge!(other_hash_serializable.registered_serializers)
        if include_attributes
          attributes.concat(other_hash_serializable.attributes)
          attribute_defaults.merge!(other_hash_serializable.attribute_defaults)
        end
        @key_transformer ||= other_hash_serializable.key_transformer
        schema_options.merge!(other_hash_serializable.schema_options)
      end

      def ref_name
        @name
      end

      def transform_keys(method = nil, &block)
        @key_transformer = block || method
      end

      def key_transformer
        @key_transformer
      end

      def key_inflection(inflection)
        # :camel_lower, :dash, :underscore, :camel, :unaltered
        transform_keys(CaseTransform.method(inflection))
      end

      def one_of(&)
        combo_serializer('one_of', &)
      end

      def any_of(&)
        combo_serializer('any_of', &)
      end

      def all_of(&)
        combo_serializer('all_of', &)
      end

      def combo_serializer(type, &)
        raise DeclarationError, 'Can only define one of `one_of`/`all_of`/`any_of`' if @combo

        @combo = ComboDSL.new(self, type).invoke(&)
      end

      ##
      # Declare an alias for a serializer.
      # For example, if you define a custom +UriSerializer+ class, you can register an alias to allow you
      # to use +:uri+ in your attribute definitions instead of the instance.
      #
      # When you use the +Serializer+ base class, common primitives such as +:string+ are already registered.
      #
      # Options:
      # [with_optional]   Also register an optional form of the serializer with a trailing question mark,
      #                       e.g. +:uri? => UriSerializer.optional+
      # [override]        By default, registering twice with the same name is forbidden. You can declare this
      #                       intention explicitly by setting this to true.
      # [aliases]         An array of other names to also use with the same serializer.
      # rubocop:disable Metrics/ParameterLists
      def register_serializer(name, serializer, with_optional: true, override: false, aliases: [], default_options: {})
        if !override && registered_serializers[name.to_s]
          raise DeclarationError, "Serializer alias #{name} has already been registered. If you wish to " \
                                  'override the alias, pass option `override: true`'
        end
        registered_serializers[name.to_s] = [serializer, default_options]
        register_serializer("#{name}?", serializer.optional, with_optional: false, override:) if with_optional
        aliases.each do |alias_name|
          register_serializer(alias_name, serializer, with_optional:, override:)
        end
        name
      end
      # rubocop:enable Metrics/ParameterLists

      def serialize(resource, options = {})
        return @combo.serialize(resource, **options) if @combo

        serializer_instance = new(resource, options)
        attributes.each_with_object({}) do |attribute, hash|
          next if attribute.skip?(serializer_instance)

          hash[attribute.key(serializer_instance)] = attribute.serialize(serializer_instance)
        end
      end

      def schema(**additional_options)
        additional_options = additional_options.dup
        return @combo.schema(**additional_options) if @combo

        HashSchemaGenerator.new(self, additional_options).schema
      end

      def lookup_serializer(alias_name)
        return alias_name if alias_name.respond_to?(:serialize)

        serializer, = registered_serializers[alias_name.to_s]
        raise DeclarationError, "Serializer for alias not found: #{alias_name.inspect}" unless serializer

        serializer
      end
    end

    extend ClassMethods
    attr_reader :object, :options

    def initialize(object, options)
      @object = object
      @options = options
    end

    def self.inherited(child_class)
      child_class.extend(ClassMethods)
      child_class.inherit_configuration_from(self, include_attributes: true)
      super
    end
  end
end
