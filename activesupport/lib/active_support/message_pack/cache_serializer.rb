# frozen_string_literal: true

require_relative "serializer"

module ActiveSupport
  module MessagePack
    module CacheSerializer
      include Serializer
      extend self

      def load(dumped)
        super
      rescue ActiveSupport::MessagePack::MissingClassError => error
        # An entry that references a missing class (e.g. renamed or removed on a
        # deploy) must be a cache miss, not a cached nil. Raise the error the
        # store rescues as a miss, like the Marshal serializer does.
        raise ActiveSupport::Cache::DeserializationError, error.message
      end

      private
        def install_unregistered_type_handler
          Extensions.install_unregistered_type_fallback(message_pack_factory)
        end
    end
  end
end
