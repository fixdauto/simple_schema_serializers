# frozen_string_literal: true

require File.expand_path('../spec_helper', __dir__)

describe 'Built-in serializers' do
  before do
    stub_const('BuiltinSpecSerializer', Class.new(SimpleSchemaSerializers::Serializer) do
      attribute 'string', :string
      attribute 'optional_string', :string?
      attribute 'integer', :integer
      attribute 'optional_integer', :integer?
      attribute 'float', :float
      attribute 'optional_float', :float?
      attribute 'double', :double
      attribute 'optional_double', :double?
      attribute 'decimal', :decimal
      attribute 'optional_decimal', :decimal?
      attribute 'boolean', :boolean
      attribute 'optional_boolean', :boolean?
      attribute 'bool', :bool
      attribute 'optional_bool', :bool?
      attribute 'datetime', :datetime
      attribute 'optional_datetime', :datetime?
      attribute 'date', :date
      attribute 'optional_date', :date?

      attribute 'rounded_float', :float, round: 2
      attribute 'rounded_decimal', :decimal, round: 2
      attribute 'rounded_double', :double, round: 4

      attribute 'anyhash', :arbitrary_hash
      attribute 'optional_anyhash', :arbitrary_hash?
    end)
  end

  before do
    stub_const('BuiltInObject', double(:built_in_object,
                                       string: 'string',
                                       optional_string: nil,
                                       integer: 0,
                                       optional_integer: nil,
                                       float: 3.14,
                                       optional_float: nil,
                                       double: 3.14,
                                       optional_double: nil,
                                       decimal: 3.14,
                                       optional_decimal: nil,
                                       boolean: true,
                                       optional_boolean: nil,
                                       bool: false,
                                       optional_bool: nil,
                                       datetime: Time.new(2020, 1, 23, 11, 59, 30, '-05:00'),
                                       optional_datetime: nil,
                                       date: Date.new(2020, 1, 23),
                                       optional_date: nil,
                                       rounded_float: Math::PI,
                                       rounded_decimal: Math::PI,
                                       rounded_double: Math::PI,
                                       anyhash: {
                                         'foo' => 'bar',
                                         baz: true
                                       },
                                       optional_anyhash: nil))
  end

  it 'should serialize the default primitive types and their optionals' do
    expect(BuiltinSpecSerializer.serialize(BuiltInObject)).to eq(
      'string' => 'string',
      'optional_string' => nil,
      'integer' => 0,
      'optional_integer' => nil,
      'float' => 3.14,
      'optional_float' => nil,
      'double' => 3.14,
      'optional_double' => nil,
      'decimal' => 3.14,
      'optional_decimal' => nil,
      'boolean' => true,
      'optional_boolean' => nil,
      'bool' => false,
      'optional_bool' => nil,
      'datetime' => '2020-01-23T11:59:30.000-05:00',
      'optional_datetime' => nil,
      'date' => '2020-01-23',
      'optional_date' => nil,
      'rounded_float' => 3.14,
      'rounded_decimal' => 3.14,
      'rounded_double' => 3.1416,
      'anyhash' => {
        'foo' => 'bar',
        'baz' => true
      },
      'optional_anyhash' => nil
    )
  end

  before do
    stub_const('StringSerializer', Class.new do
      extend SimpleSchemaSerializers::Serializable
      def self.serialize(resource, _scope = {})
        resource.to_s
      end

      def self.schema(additional_options = {})
        { type: 'string' }.merge(additional_options)
      end
    end)
  end

  describe SimpleSchemaSerializers::OptionalSerializer do
    context 'primitives' do
      it 'should serialize optional properties' do
        expect(StringSerializer.optional.serialize('foo')).to eq 'foo'
        expect(StringSerializer.optional.serialize(nil)).to eq nil
      end

      it 'should provide a schema' do
        expect(StringSerializer.optional.schema).to eq(
          'type' => ['string', 'null']
        )
      end
    end

    context 'hashes' do
      it 'should serialize optional properties' do
        expect(BuiltinSpecSerializer.optional.serialize(BuiltInObject)).to be_a Hash
        expect(BuiltinSpecSerializer.optional.serialize(nil)).to eq nil
      end

      it 'should provide a schema' do
        schema = BuiltinSpecSerializer.optional.schema
        expect(schema['oneOf']).to be_an Array
        expect(schema['oneOf'][0]).to eq('type' => 'null')
        expect(schema['oneOf'][1]['type']).to eq 'object'
      end
    end
  end

  describe SimpleSchemaSerializers::ArraySerializer do
    it 'should serialize collections' do
      expect(StringSerializer.array.serialize([:foo, :bar, :baz])).to eq ['foo', 'bar', 'baz']
    end

    it 'should provide a schema' do
      expect(StringSerializer.array.schema).to eq(
        'type' => 'array',
        'items' => { 'type' => 'string' }
      )
    end
  end
end
