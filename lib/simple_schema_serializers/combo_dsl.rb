# frozen_string_literal: true

require 'simple_schema_serializers/declaration_error'
require 'simple_schema_serializers/combo_serializer'

module SimpleSchemaSerializers
  # methods for the block scope of `one_of`/`any_of`/`all_of` methods
  class ComboDSL
    def initialize(parent, type)
      @parent = parent
      @type = type
      @options = {}
    end

    def option(name, serializer = nil, &block)
      raise DeclarationError, "Must specify or declare a serializer for option #{name}" unless serializer || block

      unless serializer
        serializer = Class.new(HashSerializer)
        serializer.inherit_configuration_from(@parent, include_attributes: false)
        serializer.instance_exec(&block)
      end
      @options[name] = serializer
    end

    def selector(&block)
      raise DeclarationError, 'Defining a selector is not supported for `all_of`' if @type == 'all_of'

      @selector = block
    end

    def invoke(&)
      instance_exec(&)
      raise DeclarationError, "Must define at least one `option` for `#{@type}`" if @options.empty?

      ComboSerializer.new(@type, @options, @selector)
    end
  end
end
