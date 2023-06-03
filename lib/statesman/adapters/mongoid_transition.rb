# Restored mongoid support, fixes applied: concernized the module and added includes + fields
# Extracted from commit b9906ee1cf0ac6c1bbdd56c003ffe407c2f59833

module Statesman
  module Adapters
    module MongoidTransition
      extend ActiveSupport::Concern

      included do
        include ::Mongoid::Document
        include ::Mongoid::Timestamps

        field :to_state,           type: String
        field :statesman_metadata, type: Hash
        field :sort_key,           type: Integer
        field :most_recent,        type: ::Mongoid::Boolean

        self.send(:alias_method, :metadata, :statesman_metadata)
        self.send(:alias_method, :metadata=, :statesman_metadata=)
      end
    end
  end
end
