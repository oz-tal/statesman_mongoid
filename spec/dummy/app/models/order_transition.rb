# frozen_string_literal: true

class OrderTransition
  include Mongoid::Document
  include Mongoid::Timestamps
  include Statesman::Adapters::MongoidTransition

  field :to_state, type: String
  field :from_state, type: String
  field :sort_key, type: Integer
  field :statesman_metadata, type: Hash
  field :most_recent, type: Mongoid::Boolean

  index({ sort_key: 1 })
  index({ order_id: 1, sort_key: -1 })
  index({ order_id: 1, most_recent: 1 }, sparse: true)

  belongs_to :order, index: true
end
