# Restored mongoid support with feature parity
# Extracted from commit b9906ee1cf0ac6c1bbdd56c003ffe407c2f59833

module Statesman
  module Adapters
    class Mongoid
      attr_reader :transition_class
      attr_reader :parent_model

      def initialize(transition_class, parent_model, observer, _opts = {})
        @transition_class = transition_class
        @parent_model = parent_model
        @observer = observer
        unless transition_class_hash_fields.include?("statesman_metadata")
          raise UnserializedMetadataError, metadata_field_error_message
        end
      end

      def create(from, to, metadata = {})
        from = from.to_s
        to = to.to_s
        transition = transitions_for_parent.build(to_state: to,
                                                  sort_key: next_sort_key,
                                                  statesman_metadata: metadata)

        transition.with_session do |session|
          @observer.execute(:before, from, to, transition)

          transition.save!

          @last_transition = transition
          @observer.execute(:after, from, to, transition)
          # TODO: Create `add_after_commit_callback` method (require expected callback support in the upcoming Mongoid 9.0)
          @observer.execute(:after_commit, from, to, transition)
        end

        transition
      ensure
        @last_transition = nil
      end

      def history(force_reload: false)
        reset if force_reload
        transitions_for_parent.asc(:sort_key)
      end

      def last(force_reload: false)
        if force_reload
          @last_transition = history(force_reload: true).last
        else
          @last_transition ||= history.last
        end
      end

      def reset
        # Aggressive, but the query cache can't be targeted at a more granular level
        ::Mongoid::QueryCache.clear_cache
      end


      private

      def transition_class_hash_fields
        transition_class.fields.select { |_, v| v.type == Hash }.keys
      end

      def metadata_field_error_message
        "#{transition_class.name}#statesman_metadata is not of type 'Hash'"
      end

      def transitions_for_parent
        @parent_model.send(@transition_class.collection_name)
      end

      def next_sort_key
        (last && last.sort_key + 10) || 10
      end
    end
  end
end
