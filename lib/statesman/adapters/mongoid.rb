# frozen_string_literal: true

# Mongoid adapter for Statesman with transaction support
#
# Supports two modes of operation:
# 1. With transactions (Mongoid 9+ and replica set): Full ACID compliance
# 2. Without transactions (Mongoid 8.x or standalone): Fallback to session-only
#
# Transaction support enables:
# - Proper after_commit callback timing (fires only after successful commit)
# - Atomic updates when using most_recent optimization
# - Rollback on errors

module Statesman
  module Adapters
    # Mongoid adapter for Statesman state machine transitions.
    #
    # Provides MongoDB persistence for state transitions with optional
    # transaction support when running Mongoid 9+ with a replica set.
    class Mongoid
      attr_reader :transition_class, :parent_model

      DUPLICATE_KEY_ERROR_CODE = 11_000

      def initialize(transition_class, parent_model, observer, opts = {})
        @transition_class = transition_class
        @parent_model = parent_model
        @observer = observer
        @opts = opts

        return if transition_class_hash_fields.include?('statesman_metadata')

        raise UnserializedMetadataError, metadata_field_error_message
      end

      def create(from, to, metadata = {})
        from = from.to_s
        to = to.to_s
        transition = build_transition(from, to, metadata)

        if StatesmanMongoid.transactions_available?
          create_with_transaction(transition, from, to)
        else
          create_without_transaction(transition, from, to)
        end
      rescue ::Mongo::Error::OperationFailure => e
        handle_operation_failure(e)
      end

      def history(force_reload: false)
        reset if force_reload
        transitions_for_parent.asc(:sort_key)
      end

      def last(force_reload: false)
        if force_reload
          @last_transition = history(force_reload: true).last
        elsif instance_variable_defined?(:@last_transition)
          @last_transition
        else
          @last_transition = history.last
        end
      end

      def reset
        clear_query_cache
        remove_instance_variable(:@last_transition) if instance_variable_defined?(:@last_transition)
      end

      private

      def build_transition(from, to, metadata)
        transition_attributes = {
          to_state: to,
          sort_key: next_sort_key,
          statesman_metadata: metadata
        }

        # Add from_state if the transition class supports it (Statesman 13.1+)
        transition_attributes[:from_state] = from if transition_class.fields.key?('from_state')

        # Set most_recent if using optimization and transactions are available
        transition_attributes[:most_recent] = true if use_most_recent? && StatesmanMongoid.transactions_available?

        transitions_for_parent.build(transition_attributes)
      end

      # Full transaction mode (Mongoid 9+ with replica set)
      # - Proper atomic commits
      # - after_commit fires only after successful transaction commit
      def create_with_transaction(transition, from, to)
        transition_class.transaction do
          @observer.execute(:before, from, to, transition)

          # Update previous most_recent flag within transaction
          update_most_recents if use_most_recent?

          transition.save!
          @last_transition = transition
          @observer.execute(:after, from, to, transition)
        end

        # after_commit fires only after successful transaction commit
        @observer.execute(:after_commit, from, to, transition)
        transition
      rescue ::Mongoid::Errors::Rollback
        reset
        raise Statesman::TransitionFailedError, 'Transaction was rolled back'
      end

      # Fallback mode (Mongoid 8.x or standalone MongoDB)
      # - Session-only (no transaction atomicity)
      # - after_commit fires immediately after save
      def create_without_transaction(transition, from, to)
        transition.with_session do |_session|
          @observer.execute(:before, from, to, transition)
          transition.save!
          @last_transition = transition
          @observer.execute(:after, from, to, transition)
          @observer.execute(:after_commit, from, to, transition)
        end

        transition
      end

      def handle_operation_failure(error)
        if duplicate_key_error?(error)
          reset
          raise Statesman::TransitionConflictError, error.message
        end
        raise
      end

      def duplicate_key_error?(error)
        error.code == DUPLICATE_KEY_ERROR_CODE
      end

      def use_most_recent?
        transition_class.fields.key?('most_recent')
      end

      def update_most_recents
        transitions_for_parent
          .where(most_recent: true)
          .update_all(most_recent: false)
      end

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
        (last && (last.sort_key + 10)) || 10
      end

      # Clear query cache - handles both Mongoid 8 and 9 APIs
      def clear_query_cache
        return unless defined?(::Mongoid::QueryCache) && ::Mongoid::QueryCache.respond_to?(:clear_cache)

        # Mongoid 8.x
        ::Mongoid::QueryCache.clear_cache

        # Mongoid 9.x doesn't have a global query cache to clear in the same way
        # The query cache is now per-request/thread and managed differently
      end
    end
  end
end
