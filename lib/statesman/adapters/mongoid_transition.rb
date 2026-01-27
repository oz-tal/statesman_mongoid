# frozen_string_literal: true

# MongoidTransition concern for Statesman transition models
#
# Include this in your transition model to get the required fields and indexes.
# Fields:
# - to_state: The target state of this transition
# - from_state: The source state (optional, for Statesman 13.1+ compatibility)
# - sort_key: Integer for ordering transitions
# - statesman_metadata: Hash for storing transition metadata
# - most_recent: Boolean flag for query optimization (used when transactions available)
#
# Example:
#   class OrderTransition
#     include Mongoid::Document
#     include Statesman::Adapters::MongoidTransition
#     belongs_to :order, index: true
#   end

require 'active_support/concern'

module Statesman
  module Adapters
    # ActiveSupport::Concern that adds required fields and indexes to Mongoid transition models.
    # Include this in your transition document class along with the parent association.
    module MongoidTransition
      extend ActiveSupport::Concern

      included do
        include ::Mongoid::Document
        include ::Mongoid::Timestamps

        field :to_state,           type: String
        field :from_state,         type: String
        field :statesman_metadata, type: Hash
        field :sort_key,           type: Integer
        field :most_recent,        type: ::Mongoid::Boolean

        index({ sort_key: 1 })

        # Alias metadata for convenience
        alias_method :metadata, :statesman_metadata
        alias_method :metadata=, :statesman_metadata=
      end
    end
  end
end
