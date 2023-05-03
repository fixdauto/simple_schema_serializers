# frozen_string_literal: true

require 'simple_schema_serializers/serializable'

module SimpleSchemaSerializers
  ##
  # A wrapper serializer for allowing options to be defined. Can be overridden by the regular
  # serializer methods.
  #
  # You can get an instance of this by calling +with_options+ on any other +Serializable+.
  class ScopedSerializer
    include Serializable

    def initialize(delegate, default_options)
      @delegate = delegate
      @default_options = default_options
    end

    def serialize(resource, **options)
      @delegate.serialize(resource, **@default_options.merge(options))
    end

    def schema(**additional_options)
      @delegate.schema(**@default_options.merge(additional_options))
    end

    def inspect
      "#{self.class.name}<#{@delegate.inspect}>"
    end
  end
end
