# frozen_string_literal: true

require 'simple_schema_serializers/hash_serializer'
require 'simple_schema_serializers/default_serializers'

module SimpleSchemaSerializers
  ##
  # This is the base class to use for all of your model serializers.
  # It comes with the standard primitive aliases already defined.
  class Serializer < HashSerializer
    register_serializer :string, DefaultSerializers::StringSerializer
    register_serializer :integer, DefaultSerializers::IntegerSerializer
    register_serializer :float, DefaultSerializers::FloatSerializer, aliases: [:decimal],
                                                                     default_options: { format: 'float' }
    register_serializer :double, DefaultSerializers::FloatSerializer, default_options: { format: 'double' }
    register_serializer :boolean, DefaultSerializers::BooleanSerializer, aliases: [:bool]
    register_serializer :arbitrary_hash, DefaultSerializers::ArbitraryHashSerializer, aliases: [:hash, :dict, :map]

    # The default serialization for dates and times (Date, DateTime, Time, etc.) is iso8601
    # but feel free to override these with a different implementation if you use a different format
    register_serializer :datetime, DefaultSerializers::ISO8601DateTimeSerializer
    register_serializer :date, DefaultSerializers::ISO8601DateSerializer
  end
end
