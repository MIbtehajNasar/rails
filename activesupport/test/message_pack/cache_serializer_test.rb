# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/message_pack"
require_relative "shared_serializer_tests"

class MessagePackCacheSerializerTest < ActiveSupport::TestCase
  include MessagePackSharedSerializerTests

  test "uses #to_msgpack_ext and ::from_msgpack_ext to roundtrip unregistered objects" do
    assert_roundtrip DefinesFromMsgpackExt.new("foo")
  end

  test "uses #as_json and ::json_create to roundtrip unregistered objects" do
    assert_roundtrip DefinesJsonCreate.new("foo")
  end

  test "raises error when unable to serialize an unregistered object" do
    assert_raises ActiveSupport::MessagePack::UnserializableObjectError do
      dump(Unserializable.new("foo"))
    end
  end

  test "raises error when serializing an unregistered object with an anonymous class" do
    assert_raises ActiveSupport::MessagePack::UnserializableObjectError do
      dump(Class.new(DefinesFromMsgpackExt).new("foo"))
    end
  end

  test "treats a missing class as a cache miss by raising DeserializationError" do
    klass = Class.new(DefinesFromMsgpackExt)
    def klass.name; "DoesNotActuallyExist"; end

    dumped = dump(klass.new("foo"))
    assert_not_nil dumped
    # A missing class must raise (which the cache store treats as a miss), not
    # return nil (which the store would treat as a cached nil). See #59681.
    assert_raises(ActiveSupport::Cache::DeserializationError) { load(dumped) }
  end

  test "a cache store treats a cached object of a missing class as a miss, not a cached nil" do
    klass = Class.new(DefinesFromMsgpackExt)
    def klass.name; "DoesNotActuallyExist"; end

    cache = ActiveSupport::Cache::MemoryStore.new(serializer: :message_pack)
    cache.write("key", klass.new("foo"))

    recomputed = false
    value = cache.fetch("key") do
      recomputed = true
      "recalculated"
    end

    assert recomputed, "fetch should treat the missing class as a miss and call the block"
    assert_equal "recalculated", value
  end

  private
    def serializer
      ActiveSupport::MessagePack::CacheSerializer
    end

    class HasValue
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def ==(other)
        self.class == other.class && value == other.value
      end
    end

    class DefinesJsonCreate < HasValue
      def self.json_create(hash)
        DefinesJsonCreate.new(hash["as_json"])
      end

      def as_json
        { "as_json" => value }
      end
    end

    class DefinesFromMsgpackExt < DefinesJsonCreate
      def self.from_msgpack_ext(string)
        DefinesFromMsgpackExt.new(string.chomp!("msgpack_ext"))
      end

      def to_msgpack_ext
        value + "msgpack_ext"
      end
    end

    class Unserializable < HasValue
      def as_json
        {}
      end

      def to_msgpack_ext
        ""
      end
    end
end
