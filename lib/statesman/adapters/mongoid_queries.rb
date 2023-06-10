# frozen_string_literal: true

# Based on the somewhat compatible ActiveRecordQueries at commit 455a21dd74bb7d3b7555de0dd66e2ece9461c22d

module Statesman
  module Adapters
    module MongoidQueries
      def self.check_missing_methods!(base)
        missing_methods = %i[transition_class initial_state].
          reject { |m| base.respond_to?(m) }
        return if missing_methods.none?

        raise NotImplementedError,
              "#{missing_methods.join(', ')} method(s) should be defined on " \
              "the model. Alternatively, use the new form of `include " \
              "Statesman::Adapters::MongoidQueries[" \
              "transition_class: MyTransition, " \
              "initial_state: :some_state]`"
      end

      def self.included(base)
        check_missing_methods!(base)

        base.include(
          ClassMethods.new(
            transition_class: base.transition_class,
            initial_state: base.initial_state,
            most_recent_transition_alias: base.try(:most_recent_transition_alias),
            transition_name: base.try(:transition_name),
          ),
        )
      end

      def self.[](**args)
        ClassMethods.new(**args)
      end

      class ClassMethods < Module
        def initialize(**args)
          @args = args
        end

        def included(base)
          ensure_inheritance(base)

          query_builder = QueryBuilder.new(base, **@args)

          define_in_state(base, query_builder)
          define_not_in_state(base, query_builder)

          define_method(:reload) do |*a|
            instance = super(*a)
            if instance.respond_to?(:state_machine, true)
              instance.state_machine.reset
            end
            instance
          end
        end

        private

        def ensure_inheritance(base)
          klass = self
          existing_inherited = base.method(:inherited)
          base.define_singleton_method(:inherited) do |subclass|
            existing_inherited.call(subclass)
            subclass.send(:include, klass)
          end
        end

        def define_in_state(base, query_builder)
          base.define_singleton_method(:in_state) do |*states|
            query_builder.states_where(states.flatten)
          end
        end

        def define_not_in_state(base, query_builder)
          base.define_singleton_method(:not_in_state) do |*states|
            query_builder.states_where_not(states.flatten)
          end
        end
      end

      class QueryBuilder
        def initialize(model, transition_class:, initial_state:,
                       most_recent_transition_alias: nil,
                       transition_name: nil)
          @model = model
          @transition_class = transition_class
          @initial_state = initial_state
          @most_recent_transition_alias = most_recent_transition_alias
          @transition_name = transition_name
        end

        def states_where(states)
          ids = aggregate_ids_for_most_recent(states, inclusive_match: true)

          if initial_state.to_s.in?(states.map(&:to_s))
            all_ids = aggregate_ids_for_all_state(states)
            ids += model.where(_id: { '$nin' => all_ids }).pluck(:id)
          end

          model.where(_id: { '$in' => ids })
        end

        def states_where_not(states)
          ids = aggregate_ids_for_most_recent(states, inclusive_match: false)

          unless initial_state.to_s.in?(states.map(&:to_s))
            all_ids = aggregate_ids_for_all_state(states)
            ids += model.where(_id: { '$nin' => all_ids }).pluck(:id)
          end

          model.where(_id: { '$in' => ids })
        end

        def aggregate_ids_for_all_state(states)
          aggregation = [
            # Group by foreign key
            {
              '$group': {
                _id: "$#{model_foreign_key}",
                model_foreign_key => { '$first': "$#{model_foreign_key}" },
              },
            },
            # Trim response to only the foreign key
            { '$project': { _id: 0 } },
          ]

          # Hit the database and return a flat array of ids
          transition_class.collection.aggregate(aggregation).pluck(model_foreign_key)
        end

        def aggregate_ids_for_most_recent(states, inclusive_match: true)
          aggregation = [
            # Sort most recent
            { '$sort': { sort_key: -1 } },
            # Group by foreign key & get most recent states
            {
              '$group': {
                _id: "$#{model_foreign_key}",
                to_state: { '$first': '$to_state' },
                model_foreign_key => { '$first': "$#{model_foreign_key}" },
              },
            },
            # Include/exclude states by provided states
            { '$match': { to_state: { (inclusive_match ? '$in' : '$nin') => states } } },
            # Trim response to only the foreign key
            { '$project': { _id: 0, to_state: 0 } },
          ]

          # Hit the database and return a flat array of ids
          transition_class.collection.aggregate(aggregation).pluck(model_foreign_key)
        end


        private

        attr_reader :model, :transition_class, :initial_state

        def transition_name
          @transition_name || transition_class.collection.name.to_sym
        end

        def transition_reflection
          model.reflect_on_all_associations(:has_many).each do |value|
            return value if value.klass == transition_class
          end

          raise MissingTransitionAssociation,
                "Could not find has_many association between #{self.class} " \
                "and #{transition_class}."
        end

        def model_primary_key
          transition_reflection.primary_key
        end

        def model_foreign_key
          transition_reflection.foreign_key
        end

        def model_table
          transition_reflection.name
        end

        def most_recent_transition_alias
          @most_recent_transition_alias ||
            "most_recent_#{transition_name.to_s.singularize}"
        end
      end
    end
  end
end
