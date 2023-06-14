require "statesman/adapters/mongoid_transition"
require "statesman/adapters/mongoid_queries"
require "mongoid"

Mongoid.configure do |config|
  config.connect_to("statesman_test")
end

class MyStateMachine
  include Statesman::Machine

  state :initial, initial: true
  state :succeeded
  state :failed

  transition from: :initial, to: %i[succeeded failed]
  transition from: :failed,  to: :initial
end

class MyMongoidModelTransition
  include Mongoid::Document
  include Mongoid::Timestamps

  field :to_state, type: String
  field :sort_key, type: Integer
  field :statesman_metadata, type: Hash

  index(sort_key: 1)

  belongs_to :my_mongoid_model, index: true

  include Statesman::Adapters::MongoidTransition
end

class MyMongoidModel
  include Mongoid::Document

  field :current_state, type: String

  has_many :my_mongoid_model_transitions

  include Statesman::Adapters::MongoidQueries[
    transition_class: MyMongoidModelTransition,
    initial_state: :initial
  ]

  def state_machine
    @state_machine ||= MyStateMachine.new(
      self, transition_class: MyMongoidModelTransition
    )
  end
end

class OtherMongoidModelTransition
  include Mongoid::Document
  include Mongoid::Timestamps

  field :to_state, type: String
  field :sort_key, type: Integer
  field :statesman_metadata, type: Hash

  index(sort_key: 1)

  belongs_to :my_mongoid_model, index: true

  include Statesman::Adapters::MongoidTransition
end

class OtherMongoidModel
  include Mongoid::Document

  field :current_state, type: String

  has_many :my_mongoid_model_transitions

  def state_machine
    @state_machine ||= MyStateMachine.new(
      self, transition_class: OtherMongoidModelTransition
    )
  end
end
