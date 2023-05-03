Simple Schema Serializers
=========================

This gem provides a simple way to build systems for serializing Ruby classes into JSON. It's modeled after [Active Model Serializers](https://github.com/rails-api/active_model_serializers) but is simpler, faster, and maintained.

```ruby
gem 'simple_schema_serializers', git: 'https://github.com/fixdauto/simple_schema_serializers.git', ref: 'v2.0.0'
```

Example
-------

```ruby
class UserSerializer < ApplicationSerializer
	defines 'User'

	attribute :name, :string
	attribute :email, :string

	array_attribute :groups do
		items GroupSerializer
	end

	def name
		object.name.split('@').first ||  object.email
	end
end
```

Usage
-----

A serializer class starts with a `defines` call, which specifies a name for the type of the object being serialized, and is followed by various attribute definitions which define keys for the output JSON object.

It should be noted that the serializer can get access to the specific source instance of the data being serialized via the `object` method. Any options given during its initialization can be accessed via the `options` method.

### Attributes

All attributes have some common options that can be specified for them:

<dl>
	<dt><code>source</code></dt>
	<dd>Specifies a name for an alternate source for the data to be placed in the JSON object property instead of the name of the attribute.</dd>
	<dt><code>if</code></dt>
	<dd>Only include the key in the output if the provided condition is true. This may be a callable, such as a lambda, or a symbol representing a source.</dd>
	<dt><code>required</code></dt>
	<dd>If true, the attribute must have a value. If this is not specified, it defaults to true unless the attribute has had `hidden` or `if` specified.</dd>
	<dt><code>hidden</code></dt>
	<dd>Don't include this attribute in the output.</dd>
	<dt><code>default</code></dt>
	<dd>The value to use if the source is nil.</dd>
	<dt><code>allow_missing_key</code></dt>
	<dd>If true and the source is a Hash, use nil for missing keys instead of throwing an error.</dd>
</dl>

#### `attribute(name: symbol, serializer: symbol | Serializer, **options)`

The simplest attribute type. This defines a single key with a serializer. The serializer can be either a class that implements serializer, a built-in type, or a type registered with `register_serializer`. For more information, see the section on serializer types below.

The source of the data defaults to a method of the original object with the same name or with the name specified by the `source` option. If a method with the same name exists in the serializer itself, that method will be called to get the data instead.

#### `array_attribute(name: symbol, **options, &block)`

Defines an attribute containing an array of items. The inside of the block provides the following methods:

##### `items(serializer: Serializer, **options, &block)`

Specifies the serializer to use for the items of the array. If no serializer is provided, the block acts the same as the block of `hash_attribute`.

#### `hash_attribute(name: symbol, **options, &block)`

Defines an attribute that contains an object. The inside of the block has all of the same methods available that are available at the top-level, essentially allowing you to structure the data into a hierarchy that doesn't match the original data.

#### `remove_attribute(name: symbol)`

Removes a previously defined attribute.

### Serializer Interface

A `Serializer` is an object that can transform one value to another and report it's `json-schema`. It should respond to `serialize(resource, **options)` and `schema(**additional_options)` and include methods from `Serializable`.  Thus, any serializer can be invoked with `Serializer.serialize(resource)`. This allows you to create custom serializers for primitive types and more complex outputs. For example:

```ruby
class StringSerializer
  extend Serializable

  ##
  # @param resource The object to serialize
  # @param [Hash] options Optional additional context to control the behavior of the serializer
  def self.serialize(resource, **)
    resource.to_s
  end

  ##
  # @return [Hash] The JSON-Schema definition of the serializer output
  def self.schema(**additional_options)
    { type: :string }.merge(additional_options)
  end
end
```

`Serializable` provides `array` and `optional` wrapper serializers. For example:

```ruby
StringSerializer.optional.serialize(nil) # nil
StringSerializer.array.serialize([:foo, :bar]) # ["foo", "bar"]
```

It also provides `with_options`, which will set the default options for the serializer:

```ruby
MoneySerializer.with_options(currency: 'CAD').serialize(0.to_money('USD'))
```

`SimpleSchemaSerializers::Serializer` is a base class for building serializers for objects using a DSL.

### Serializer Types

The `attribute` method can take any serializer as its type. For example:

```ruby
class FooSerializer < SimpleSchemaSerializers::Serializer
  attribute :bar, BarSerializer
  attribute :baz, StringSerializer.optional.array
end
```

For brevity, serializers can be referenced using symbols instead of the instance itself. A `?` on the symbol name indicates an optional (nullable) value. You can register symbol aliases for common serializers using the `register_serializer` method.

```ruby
class MoneySerializer < SimpleSchemaSerializers::Serializer
  attribute :amount, :float, example: 19.99
  attribute :currency, :string, example: 'USD'
end

class ApplicationSerializer < SimpleSchemaSerializers::Serializer
  register_serializer :money, MoneySerializer
end

class ProductSerializer < ApplicationSerializer
  attribute :name, :string
  attribute :price, :money
end
```

Aliases for the following common primitive serializers are included by default:

- `:string`, `:string?`
- `:integer`, `:integer?`
- `:float`, `:float?`, `:decimal`, `:decimal?`, `:double`, `:double?`
- `:boolean`, `:boolean?`
- `:date`, `:date?`, `:datetime`, `:datetime?`
- `:arbitrary_hash`, `:arbitrary_hash?`

### Key transformations

Methods can be registered to transform keys from their attribute name. Key transformations are inherited.

```ruby
class ApplicationSerializer < SimpleSchemaSerializers::Serializer
	# can be a method on string:
	transform_keys :upper
	# or a block:
	transform_keys do |key|
		key.upper
	end
	# or a method on the serializer
	transform_keys :my_upper
	def my_upper(key)
		key.upper
	end
end
```

Most commonly, this is used for changing inflection, for example `camelCase`. These options are included:

```ruby
class ApplicationSerializer < SimpleSchemaSerializers::Serializer
	# supports :camel (aka PascalCase), :camel_lower (aka camelCase),
	#  :dash (dash-case), and :underscore (under_score)
	key_inflection :camel_lower
end
```

If you use the same inflection everywhere and you don't have dynamic keys, you can get some performance improvements by using a cache:

```ruby
require 'lru_redux'
class ApplicationSerializer < SimpleSchemaSerializers::Serializer

	KEY_CACHE = LruRedux::Cache.new(1000) # set the size based on the number of unique keys you have

	transform_keys :camelize_key

	def camelize_key(key)
		KEY_CACHE.getset(key) { CaseTransform.camel_lower(key) }
	end
end
```
