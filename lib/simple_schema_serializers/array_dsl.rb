# frozen_string_literal: true

module SimpleSchemaSerializers
  # Class for acting as block scope of `array_attribute` method
  class ArrayDSL
    def initialize(parent)
      @parent = parent
      @called = false
    end

    def items(serializer = nil, opts = {}, &block)
      raise DeclarationError, 'Called `items` twice in `array_attribute`' if @called

      @called = true
      if serializer.is_a?(Hash)
        opts = serializer.merge(opts)
        serializer = nil
      end
      if serializer
        @serializer = serializer
      elsif block
        @serializer = Class.new(HashSerializer)
        @serializer.inherit_configuration_from(@parent, include_attributes: false)
        @serializer.instance_exec(&block)
        @serializer = @serializer.optional if opts.delete(:optional)
      else
        raise DeclarationError, 'Items must specify a serializer'
      end
      @opts = opts
    end

    def invoke(&block)
      instance_exec(&block)
      raise DeclarationError, 'Must call `items` for `array_attribute`' unless @called

      [@serializer, @opts]
    end
  end
end
