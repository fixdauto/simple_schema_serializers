# frozen_string_literal: true

require File.expand_path('../spec_helper', __dir__)

describe SimpleSchemaSerializers::Serializer do
  def create_serializer(&)
    Class.new(SimpleSchemaSerializers::Serializer, &)
  end

  describe 'DSL' do
    it 'should allow defining of simple attributes' do
      serializer = create_serializer do
        attribute :foo, :string
      end
      expect(serializer.schema).to eq({
                                        'type' => 'object',
                                        'required' => ['foo'],
                                        'properties' => {
                                          'foo' => { 'type' => 'string' }
                                        }
                                      })
      expect(serializer.serialize(double(:thing, foo: 'bar'))).to eq({ 'foo' => 'bar' })
    end

    it 'should allow you to provide an implementation method' do
      serializer = create_serializer do
        attribute :hello_foo, :string

        def hello_foo
          raise StandardError, 'Missing Object' unless object
          raise StandardError, 'Missing Scope' unless options[:some] == 'scope'

          "Hello, #{object.foo}"
        end
      end

      expect(serializer.serialize(double(:thing, foo: 'bar'), some: 'scope')).to eq({ 'hello_foo' => 'Hello, bar' })
    end

    it 'should allow referencing a Serializable instance directly' do
      child_serializer = create_serializer do
        attribute :foo, :string
      end
      parent_serializer = create_serializer do
        attribute :child, child_serializer
      end

      resource = double(:parent, child: double(:child, foo: 'bar'))
      expect(parent_serializer.serialize(resource)).to eq({
                                                            'child' => {
                                                              'foo' => 'bar'
                                                            }
                                                          })
      expect(parent_serializer.schema).to eq({
                                               'type' => 'object',
                                               'required' => ['child'],
                                               'properties' => {
                                                 'child' => {
                                                   'type' => 'object',
                                                   'required' => ['foo'],
                                                   'properties' => {
                                                     'foo' => { 'type' => 'string' }
                                                   }
                                                 }
                                               }
                                             })
    end

    it 'should allow you to specify a different name for an attribute than the source object' do
      serializer = create_serializer do
        attribute :hello_foo, :string, source: :foo
      end

      expect(serializer.serialize(double(:thing, foo: 'bar'))).to eq({ 'hello_foo' => 'bar' })
    end

    describe 'Hash objects' do
      it 'should allow serializing hashes as well as objects' do
        serializer = create_serializer do
          attribute :foo, :string
        end
        expect(serializer.serialize({ foo: 'bar' })).to eq({ 'foo' => 'bar' })
      end

      it 'should allow string keys as well as symbol keys' do
        serializer = create_serializer do
          attribute :foo, :string
        end
        expect(serializer.serialize({ 'foo' => 'bar' })).to eq({ 'foo' => 'bar' })
      end

      it 'should prefer symbol keys to string keys' do
        serializer = create_serializer do
          attribute :foo, :string
        end
        expect(serializer.serialize({ 'foo' => 'string', :foo => 'symbol' })).to eq({ 'foo' => 'symbol' })
      end

      it 'should allow specifying a source key' do
        serializer = create_serializer do
          attribute :foo, :string, source: :bar
        end
        expect(serializer.serialize({ 'bar' => 'baz' })).to eq({ 'foo' => 'baz' })
      end

      it 'should error if the source is missing' do
        serializer = create_serializer do
          attribute :foo, :string
        end
        expect { serializer.serialize({ 'bar' => 'baz' }) }.to raise_error(SimpleSchemaSerializers::DeclarationError)
      end

      it 'should not error if allow_missing_key is provided' do
        serializer = create_serializer do
          attribute :foo, :string?, allow_missing_key: true
        end
        expect(serializer.serialize({ 'bar' => 'baz' })).to eq({ 'foo' => nil })
      end

      it 'should allow allow_missing_key to also be set for the whole serializer' do
        serializer = create_serializer do
          attribute_defaults allow_missing_key: true
          attribute :foo, :string?
          attribute :bar, :integer, allow_missing_key: false
          attribute :baz, :integer?
        end
        expect(serializer.serialize({ 'bar' => 1 })).to eq({ 'foo' => nil, 'bar' => 1, 'baz' => nil })
      end

      it 'should still prefer serializer methods to hash keys' do
        serializer = create_serializer do
          attribute :foo, :string
          def foo
            'foo2'
          end
        end
        expect(serializer.serialize({ 'foo' => 'foo1' })).to eq({ 'foo' => 'foo2' })
      end

      it 'should allow calling private methods from conditions' do
        serializer = create_serializer do
          attribute :test, :string, if: :test?
          private
          def test? = false
        end
        expect(serializer.serialize({ 'test' => 'bad' })).to eq({})
      end

      it 'should not error if a built-in method name is used as a hash key' do
        serializer = create_serializer do
          attribute :method, :string
        end
        expect(serializer.serialize({ 'method' => 'foo' })).to eq({ 'method' => 'foo' })
      end

      it 'should allow hidden attributes' do
        serializer = create_serializer do
          attribute :documented, :string
          attribute :undocumented, :string, hidden: true
        end
        expect(serializer.schema).to eq({
                                          'type' => 'object',
                                          'required' => ['documented'],
                                          'properties' => { 'documented' => { 'type' => 'string' } }
                                        })
        expect(serializer.serialize(double(:thing, documented: 'yes', undocumented: 'no'))).to eq(
          'documented' => 'yes',
          'undocumented' => 'no'
        )
      end
    end

    describe 'should allow conditional attributes' do
      it 'via proc' do
        serializer = create_serializer do
          attribute :conditional, :string, if: proc { object.condition }
          attribute :other, :string
        end
        yes_resource = double(:yes, conditional: 'foo', other: 'other', condition: true)
        no_resource = double(:no, conditional: 'foo', other: 'other', condition: false)

        expect(serializer.serialize(yes_resource)).to eq({ 'conditional' => 'foo', 'other' => 'other' })
        expect(serializer.serialize(no_resource)).to eq({ 'other' => 'other' })
      end

      it 'via lambda' do
        serializer = create_serializer do
          attribute :conditional, :string, if: -> { object.condition }
          attribute :other, :string
        end
        yes_resource = double(:yes, conditional: 'foo', other: 'other', condition: true)
        no_resource = double(:no, conditional: 'foo', other: 'other', condition: false)

        expect(serializer.serialize(yes_resource)).to eq({ 'conditional' => 'foo', 'other' => 'other' })
        expect(serializer.serialize(no_resource)).to eq({ 'other' => 'other' })
      end

      it 'via serializer method' do
        serializer = create_serializer do
          attribute :conditional, :string, if: :check_condition
          attribute :other, :string

          def check_condition
            object.conditional == 'foo'
          end
        end
        yes_resource = double(:yes, conditional: 'foo', other: 'other')
        no_resource = double(:no, conditional: 'bar', other: 'other')

        expect(serializer.serialize(yes_resource)).to eq({ 'conditional' => 'foo', 'other' => 'other' })
        expect(serializer.serialize(no_resource)).to eq({ 'other' => 'other' })
      end
    end

    describe 'nested serializer definitions' do
      it 'should allow defining anonymous nested serializers' do
        serializer = create_serializer do
          attribute :name, :string
          hash_attribute :child do
            attribute :foo, :string
            attribute :bar, :integer?
          end
        end

        resource = double(:parent, name: 'x', child: double(:child, foo: 'foo', bar: nil))
        expect(serializer.serialize(resource)).to eq({
                                                       'name' => 'x',
                                                       'child' => {
                                                         'foo' => 'foo',
                                                         'bar' => nil
                                                       }
                                                     })
      end

      it 'should allow defining optional anonymous nested serializers' do
        serializer = create_serializer do
          attribute :name, :string
          hash_attribute :child, optional: true do
            attribute :foo, :string
            attribute :bar, :integer?
          end
        end

        resource = double(:thing, name: 'x', child: nil)
        expect(serializer.serialize(resource)).to eq({
                                                       'name' => 'x',
                                                       'child' => nil
                                                     })
        schema = serializer.schema
        expect(schema['properties']['child']['oneOf'][0]['type']).to eq 'null'
        expect(schema['properties']['child']['oneOf'][1]['type']).to eq 'object'
      end

      it 'should allow defining anonymous nested serializers as array elements' do
        serializer = create_serializer do
          attribute :name, :string
          array_attribute :child do
            items do
              attribute :foo, :string
              attribute :bar, :integer?
            end
          end
        end

        resource = double(:parent, name: 'x', child: [double(:child, foo: 'foo', bar: nil)])
        expect(serializer.serialize(resource)).to eq({
                                                       'name' => 'x',
                                                       'child' => [{
                                                         'foo' => 'foo',
                                                         'bar' => nil
                                                       }]
                                                     })
        schema = serializer.schema
        expect(schema['properties']['child']['type']).to eq 'array'
        expect(schema['properties']['child']['items']['type']).to eq 'object'
        expect(schema['properties']['child']['items']['properties']['foo']['type']).to eq 'string'
      end

      it 'should allow defining optional anonymous nested serializers as array elements' do
        serializer = create_serializer do
          attribute :name, :string
          array_attribute :child do
            items optional: true do
              attribute :foo, :string
              attribute :bar, :integer?
            end
          end
        end

        resource = double(:parent, name: 'x', child: [nil, double(:child, foo: 'foo', bar: nil)])
        expect(serializer.serialize(resource)).to eq({
                                                       'name' => 'x',
                                                       'child' => [nil, {
                                                         'foo' => 'foo',
                                                         'bar' => nil
                                                       }]
                                                     })
        schema = serializer.schema
        expect(schema['properties']['child']['type']).to eq 'array'
        expect(schema['properties']['child']['items']['oneOf'][0]['type']).to eq 'null'
        expect(schema['properties']['child']['items']['oneOf'][1]['type']).to eq 'object'
      end

      it 'should allow defining optional arrays of nested serializers' do
        serializer = create_serializer do
          attribute :name, :string
          array_attribute :child, optional: true do
            items do
              attribute :foo, :string
              attribute :bar, :integer?
            end
          end
        end

        resource = double(:thing, name: 'x', child: nil)
        expect(serializer.serialize(resource)).to eq({
                                                       'name' => 'x',
                                                       'child' => nil
                                                     })
        schema = serializer.schema
        expect(schema['properties']['child']['oneOf'][0]['type']).to eq 'null'
        expect(schema['properties']['child']['oneOf'][1]['type']).to eq 'array'
        expect(schema['properties']['child']['oneOf'][1]['items']['type']).to eq 'object'
      end

      it 'should separate object json-schema arguments from element arguments' do
        serializer = create_serializer do
          desc 'Child object'
          hash_attribute :child, additionalProperties: true do
            attribute :foo, :string, enum: ['foo']
            attribute :bar, :integer?
          end
        end
        schema = serializer.schema
        expect(schema['properties']['child']['type']).to eq 'object'
        expect(schema['properties']['child']['description']).to eq 'Child object'
        expect(schema['properties']['child']['additionalProperties']).to eq true
        expect(schema['properties']['child']['properties']['foo']['enum']).to eq ['foo']
      end

      it 'should not use attribute implementations of the parent serializer' do
        serializer = create_serializer do
          desc 'Child object'
          attribute :foo, :string
          hash_attribute :child do
            attribute :foo, :string
          end
          array_attribute :child_array do
            items do
              attribute :foo, :string
            end
          end

          def foo
            'parent_foo'
          end
        end

        resource = double(:parent,
                          child: double(:child1, foo: 'child_foo'),
                          child_array: [double(:child2, foo: 'child_array_foo')])
        expect(serializer.serialize(resource)).to eq({
                                                       'foo' => 'parent_foo',
                                                       'child' => { 'foo' => 'child_foo' },
                                                       'child_array' => [{ 'foo' => 'child_array_foo' }]
                                                     })
      end
    end

    describe 'schema' do
      it 'should support delcaring descriptions for attributes' do
        serializer = create_serializer do
          attribute :a, :integer
          desc 'This is b'
          attribute :b, :integer
          attribute :c, :integer
        end
        expect(serializer.schema['properties']['b']['description']).to eq 'This is b'
        expect(serializer.schema['properties']['a']).not_to have_key('description')
        expect(serializer.schema['properties']['c']).not_to have_key('description')
      end

      it 'should pass json-schema arguments to the schema output' do
        serializer = create_serializer do
          attribute :foo, :string, enum: ['a', 'b', 'c'], default: 'a', minLength: 1, maxLength: 1
          attribute :email, :string?, format: :email, example: 'help@example.com', pattern: '.+@.+'
          attribute :age, :integer, description: 'inline description',
                                    multipleOf: 10, exclusiveMinimum: 0, maximum: 100, examples: [10, 20, 30, 40]
        end

        expect(serializer.schema['properties']['foo']).to eq({
                                                               'type' => 'string',
                                                               'enum' => ['a', 'b', 'c'],
                                                               'default' => 'a',
                                                               'minLength' => 1,
                                                               'maxLength' => 1
                                                             })
        expect(serializer.schema['properties']['email']).to eq({
                                                                 'type' => ['string', 'null'],
                                                                 'format' => :email,
                                                                 'example' => 'help@example.com',
                                                                 'pattern' => '.+@.+'
                                                               })
        expect(serializer.schema['properties']['age']).to eq({
                                                               'type' => 'integer',
                                                               'description' => 'inline description',
                                                               'multipleOf' => 10,
                                                               'exclusiveMinimum' => 0,
                                                               'maximum' => 100,
                                                               'examples' => [10, 20, 30, 40]
                                                             })
      end

      it 'should allow you to define object schema options' do
        serializer = create_serializer do
          schema_options required: [], minProperties: 2, maxProperties: 10
          attribute :a, :string
          attribute :b, :string
        end
        expect(serializer.schema['required']).to eq []
        expect(serializer.schema['minProperties']).to eq 2
        expect(serializer.schema['maxProperties']).to eq 10
      end

      it 'should allow declaring the object description' do
        serializer = create_serializer do
          object_description 'The description of this object'
          attribute :a, :string
          attribute :b, :string
        end
        expect(serializer.schema['description']).to eq 'The description of this object'
      end

      it 'should not require conditional attributes' do
        serializer = create_serializer do
          attribute :conditional, :string, if: proc { false }
          attribute :other, :string
        end
        expect(serializer.schema).to eq({
                                          'type' => 'object',
                                          'required' => ['other'],
                                          'properties' => {
                                            'conditional' => { 'type' => 'string' },
                                            'other' => { 'type' => 'string' }
                                          }
                                        })
      end
    end

    it 'should allow array attributes' do
      child_serializer = create_serializer do
        attribute :foo, :string
      end
      parent_serializer = create_serializer do
        array_attribute :primitive_array do
          items :string
        end
        array_attribute :object_array do
          items child_serializer
        end
      end
      resource = double(:parent, primitive_array: ['a', 'b'], object_array: [double(:child, foo: 'bar')])

      expect(parent_serializer.serialize(resource)).to eq({
                                                            'primitive_array' => ['a', 'b'],
                                                            'object_array' => [{ 'foo' => 'bar' }]
                                                          })
      expect(parent_serializer.schema['properties']['primitive_array']).to eq({
                                                                                'type' => 'array',
                                                                                'items' => { 'type' => 'string' }
                                                                              })
      expect(parent_serializer.schema['properties']['object_array']['type']).to eq 'array'
      expect(parent_serializer.schema['properties']['object_array']['items']['type']).to eq 'object'
    end

    it 'should separate json-schema arguments for array from the object ones' do
      serializer = create_serializer do
        array_attribute :array, maxItems: 2 do
          items :string, enum: ['a', 'b', 'c']
        end
      end
      expect(serializer.schema['properties']['array']['maxItems']).to eq 2
      expect(serializer.schema['properties']['array']['items']['enum']).to eq ['a', 'b', 'c']
    end

    it 'should send non-array attributes to the hash attribute' do
      serializer = create_serializer do
        array_attribute :array, maxItems: 2, if: :conditional do
          items :string
        end
      end
      expect(serializer.schema['properties']['array']['maxItems']).to eq 2
      expect(serializer.schema['required']).to be_empty
      expect(serializer.serialize(double(:thing, array: ['a'], conditional: false))).to eq({})
    end

    it 'should allow you to provide a default value' do
      serializer = create_serializer do
        attribute :foo, :string, default: 'unknown'
      end
      expect(serializer.schema['properties']['foo']['default']).to eq 'unknown'
      expect(serializer.serialize(double(:thing, foo: nil))).to eq({ 'foo' => 'unknown' })
    end

    it 'should allow you to provide attribute defaults' do
      serializer = create_serializer do
        attribute_defaults description: 'Duplicated description', if: :included
        attribute :a, :string
        attribute :b, :string

        def included
          false
        end
      end

      expect(serializer.schema['properties']['a']['description']).to eq 'Duplicated description'
      expect(serializer.schema['properties']['b']['description']).to eq 'Duplicated description'
      expect(serializer.serialize(double(:thing, a: 'a', b: 'b'))).to eq({})
    end
  end

  describe 'Inheritance' do
    before do
      stub_const('InhertianceSerializerBuilder', Class.new do
        attr_reader :child_serializer

        def parent(&)
          @parent_serializer = Class.new(SimpleSchemaSerializers::Serializer, &)
        end

        def child(&)
          @child_serializer = Class.new(@parent_serializer, &)
        end
      end)
    end

    def inherited_serializers(&)
      InhertianceSerializerBuilder.new.tap { |b| b.instance_exec(&) }.child_serializer
    end

    it 'should allow inheriting attributes' do
      child = inherited_serializers do
        parent do
          attribute :id, :integer
        end

        child do
          attribute :name, :string
        end
      end
      expect(child.serialize(double(:thing, id: 1, name: 'foo'))).to eq({ 'id' => 1, 'name' => 'foo' })
    end

    it 'should allow removing inherited attributes' do
      child = inherited_serializers do
        parent do
          attribute :id, :integer
          attribute :foo, :string
        end

        child do
          attribute :name, :string
          remove_attribute :foo
        end
      end
      expect(child.serialize(double(:thing, id: 1, foo: 'bar', name: 'foo'))).to eq({ 'id' => 1, 'name' => 'foo' })
    end

    it 'should allow inheriting attribute defaults' do
      child = inherited_serializers do
        parent do
          attribute_defaults description: 'Inherited description'
        end

        child do
          attribute :name, :string
        end
      end
      expect(child.schema['properties']['name']['description']).to eq 'Inherited description'
    end

    it 'should allow inheriting schema options' do
      child = inherited_serializers do
        parent do
          schema_options description: 'Inherited object description'
        end

        child do
          attribute :name, :string
        end
      end
      expect(child.schema['description']).to eq 'Inherited object description'
    end

    it 'should allow inheriting serializer aliases' do
      user_serializer = create_serializer do
        attribute :name, :string
      end
      child = inherited_serializers do
        parent do
          register_serializer :user, user_serializer
        end

        child do
          attribute :user, :user
        end
      end
      expect(child.serialize(double(:parent, user: double(:user, name: 'foo')))).to eq({
                                                                                         'user' => { 'name' => 'foo' }
                                                                                       })
    end

    it 'should allow inheriting validation options' do
      child = inherited_serializers do
        parent do
          validation_options strict: true
        end

        child do
          attribute :name, :string
        end
      end
      expect(child.valid?('not_name' => 'foo')).to eq false
    end

    it 'should allow inheriting key transforms' do
      child = inherited_serializers do
        parent do
          transform_keys :upcase_keys

          def upcase_keys(key)
            options[:upcase] ? key.upcase : key
          end
        end

        child do
          attribute :name, :string
        end
      end
      expect(child.serialize({ name: 'joe' }, upcase: true)).to eq({ 'NAME' => 'joe' })
    end
  end

  describe 'register_serializer' do
    it 'should allow registering serializer aliases' do
      custom_serializer = create_serializer do
        attribute :foo, :string
      end
      serializer = create_serializer do
        register_serializer :custom, custom_serializer
      end
      expect(serializer.lookup_serializer(:custom)).to eq custom_serializer
    end

    it 'should register optional aliases by default' do
      custom_serializer = create_serializer do
        attribute :foo, :string
      end
      serializer = create_serializer do
        register_serializer :custom, custom_serializer
      end
      expect(serializer.lookup_serializer(:custom?)).to be_a SimpleSchemaSerializers::OptionalSerializer
    end

    it 'should allow suppressing of generating optional aliases' do
      custom_serializer = create_serializer do
        attribute :foo, :string
      end
      serializer = create_serializer do
        register_serializer :custom, custom_serializer, with_optional: false
      end
      expect { serializer.lookup_serializer(:custom?) }.to raise_error(SimpleSchemaSerializers::DeclarationError)
    end

    it 'should allow defining additional aliases for the same serializer' do
      custom_serializer = create_serializer do
        attribute :foo, :string
      end
      serializer = create_serializer do
        register_serializer :custom, custom_serializer, aliases: [:alias1, :alias2]
      end
      expect(serializer.lookup_serializer(:custom)).to eq custom_serializer
      expect(serializer.lookup_serializer(:alias1)).to eq custom_serializer
      expect(serializer.lookup_serializer(:alias2)).to eq custom_serializer
    end

    it 'should disallow overwriting aliases by default' do
      custom_serializer = create_serializer do
        attribute :foo, :string
      end
      new_custom_serializer = create_serializer do
        attribute :foo, :integer
      end
      expect do
        create_serializer do
          register_serializer :custom, custom_serializer

          register_serializer :custom, new_custom_serializer
        end
      end.to raise_error(SimpleSchemaSerializers::DeclarationError)
    end

    it 'should allow overwriting of aliases explicitly' do
      custom_serializer = create_serializer do
        attribute :foo, :string
      end
      new_custom_serializer = create_serializer do
        attribute :foo, :integer
      end
      expect do
        serializer = create_serializer do
          register_serializer :custom, custom_serializer

          register_serializer :custom, new_custom_serializer, override: true
        end
        expect(serializer.lookup_serializer(:custom)).to eq new_custom_serializer
      end.not_to raise_error
    end
  end

  describe 'Definition references' do
    it 'should allow defining a pointer name' do
      serializer = create_serializer do
        defines 'User'
        attribute :id, :integer
        attribute :name, :string
      end
      expect(serializer.ref_name).to eq 'User'
      expect(serializer.ref_path).to eq '#/definitions/User'
    end

    it 'should use ref_names for child attribute schemas if available' do
      user_serializer = create_serializer do
        defines 'User'
        attribute :id, :integer
        attribute :name, :string
      end

      organization_serializer = create_serializer do
        defines 'Organization'
        attribute :ceo, user_serializer
        attribute :owner, user_serializer.optional
        attribute :founders, user_serializer.array.optional
        attribute :employees, user_serializer.array
      end
      # when calling schema on a serializer, the default is to use it's schema but return
      # references of it's attributes' schemas
      expect(user_serializer.schema['type']).to eq 'object'
      expect(user_serializer.schema['$ref']).to be_nil

      expect(organization_serializer.schema['properties']['ceo']).to eq({ '$ref' => '#/definitions/User' })
      expect(organization_serializer.schema['properties']['owner']['oneOf'][1]).to eq(
        {
          '$ref' => '#/definitions/User'
        }
      )
      expect(organization_serializer.schema['properties']['employees']['items']).to eq(
        {
          '$ref' => '#/definitions/User'
        }
      )
      expect(organization_serializer.schema['properties']['founders']['oneOf'][1]['items']).to eq(
        {
          '$ref' => '#/definitions/User'
        }
      )
      expect(organization_serializer.schema['type']).to eq 'object'
      expect(organization_serializer.schema['$ref']).to be_nil
    end

    it 'should allow disabling ref_names for child attribute schemas' do
      user_serializer = create_serializer do
        defines 'User'
        attribute :id, :integer
        attribute :name, :string
      end

      organization_serializer = create_serializer do
        defines 'Organization'
        attribute :ceo, user_serializer
        attribute :owner, user_serializer.optional
        attribute :founders, user_serializer.array.optional
        attribute :employees, user_serializer.array
      end
      org_schema = organization_serializer.schema(use_refs: false)
      expect(org_schema['properties']['ceo']['type']).to eq 'object'
      expect(org_schema['properties']['owner']['oneOf'][1]['type']).to eq 'object'
      expect(org_schema['properties']['employees']['items']['type']).to eq 'object'
      expect(org_schema['properties']['founders']['oneOf'][1]['items']['type']).to eq 'object'
    end

    describe 'with_options' do
      it 'should allow setting default options at the declaration level' do
        base_serializer = create_serializer do
          attribute :a, :integer
          attribute :b, :integer
          attribute :sum, :integer

          def b
            options[:b] || 0
          end

          def sum
            object.a + b
          end
        end

        add_five_serializer = base_serializer.with_options(b: 5)

        expect(base_serializer.serialize(double(a: 1))['sum']).to eq 1
        expect(add_five_serializer.serialize(double(a: 1))['sum']).to eq 6
      end
    end
  end

  describe 'Combo schemas' do
    ['one_of', 'any_of'].each do |method|
      describe method do
        it "should support defining #{method} schemas" do
          serializer = create_serializer do
            send(method) do
              option :one do
                attribute :one, :string
              end

              option :two do
                attribute :two, :integer?
              end
            end
          end
          expect(serializer.schema[method == 'one_of' ? 'oneOf' : 'anyOf'][0]['properties'].keys).to eq ['one']
          expect(serializer.schema[method == 'one_of' ? 'oneOf' : 'anyOf'][1]['properties'].keys).to eq ['two']
        end

        it 'should use a selector to determine which option is selected' do
          serializer = create_serializer do
            send(method) do
              option :one do
                attribute :one, :string
              end

              option :two do
                attribute :two, :integer?
              end

              selector do |_data, opts|
                opts[:one] ? :one : :two
              end
            end
          end
          expect(serializer.serialize({ 'one' => 'foo' }, one: true)).to eq({ 'one' => 'foo' })
          expect(serializer.serialize({ 'two' => 2 }, one: false)).to eq({ 'two' => 2 })
        end

        it 'should error if you try to serialize without specifying a selector' do
          serializer = create_serializer do
            send(method) do
              option :one do
                attribute :one, :string
              end

              option :two do
                attribute :two, :integer?
              end
            end
          end
          expect do
            serializer.serialize({ 'one' => 'foo' })
          end.to raise_error(/Must define a selector/)
        end
      end
    end

    describe 'all_of' do
      it 'should support defining all_of schemas' do
        serializer = create_serializer do
          all_of do
            option :one do
              attribute :one, :string
            end

            option :two do
              attribute :two, :integer?
            end
          end
        end
        expect(serializer.schema['allOf'][0]['properties'].keys).to eq ['one']
        expect(serializer.schema['allOf'][1]['properties'].keys).to eq ['two']
      end

      it 'should merge the results of each selector into the output' do
        serializer = create_serializer do
          all_of do
            option :one do
              attribute :one, :string
            end

            option :two do
              attribute :two, :integer?
            end
          end
        end
        expect(serializer.serialize({ one: 'one', two: 2 })).to eq({ 'one' => 'one', 'two' => 2 })
      end
    end
  end

  describe 'key transformations' do
    it 'should allow defining a key transformation method' do
      serializer = create_serializer do
        transform_keys :upcase_keys

        attribute :first_name, :string

        def upcase_keys(key)
          options[:upcase] ? key.upcase : key
        end
      end
      expect(serializer.serialize({ first_name: 'joe' }, upcase: false)).to eq({ 'first_name' => 'joe' })
      expect(serializer.serialize({ first_name: 'joe' }, upcase: true)).to eq({ 'FIRST_NAME' => 'joe' })
    end

    it 'should allow applying a key_inflection to the keys' do
      serializer = create_serializer do
        key_inflection :camel_lower
        attribute :first_name, :string
      end
      expect(serializer.serialize({ first_name: 'joe' })).to eq({ 'firstName' => 'joe' })
    end
  end
end
