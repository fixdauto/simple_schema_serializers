# frozen_string_literal: true

require 'simple_schema_serializers/declaration_error'
require 'simple_schema_serializers/serializable'

module SimpleSchemaSerializers
  # A serializer for combination schemas oneOf/anyOf/allOf.
  #
  # oneOf/anyOf are switching; a `selector` chooses based on the data and the options
  # which serializer option to use. `allOf` is merging; all the serializer options
  # are called and their results are merged into one object.
  class ComboSerializer
    KEY_NAME = { 'one_of' => 'oneOf', 'all_of' => 'allOf', 'any_of' => 'anyOf' }.freeze
    def initialize(type, options, selector)
      @type = type.to_s
      raise DeclarationError, "Invalid Combo serializer type: #{type}" unless any_of? || all_of? || one_of?

      @options = options
      @selector = selector
    end

    def schema(additional_options = {})
      { KEY_NAME[@type] => @options.map { |_, delegate| delegate.schema(additional_options) } }
    end

    def serialize(resource, options = {})
      if merge?
        return @options.each_with_object({}) do |(_name, delegate), hash|
          hash.merge!(delegate.serialize(resource, options))
        end
      end
      # otherwise use selector
      raise DeclarationError, "Must define a selector to use #{@type} serializer" unless @selector

      option_name = @selector.call(resource, options)
      unless @options[option_name]
        raise DeclarationError, "Invalid option selected: #{option_name}. Declared options are: #{@options.keys}"
      end

      @options[option_name].serialize(resource, options)
    end

    def any_of?
      @type == 'any_of'
    end

    def one_of?
      @type == 'one_of'
    end

    def all_of?
      @type == 'all_of'
    end

    def inspect
      "#{self.class.name}<#{options.map { |n, v| "#{n}:#{v.inspect}" }.join(', ')}>"
    end

    protected

    def merge?
      all_of?
    end
  end
end
