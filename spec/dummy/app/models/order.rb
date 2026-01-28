# frozen_string_literal: true

class Order
  include Mongoid::Document
  include Mongoid::Timestamps

  field :reference, type: String
  field :amount, type: Integer

  has_many :order_transitions, autosave: false

  include Statesman::Adapters::MongoidQueries[
    transition_class: OrderTransition,
    initial_state: :pending
  ]

  def state_machine
    @state_machine ||= OrderStateMachine.new(
      self,
      transition_class: OrderTransition,
      association_name: :order_transitions
    )
  end

  delegate :can_transition_to?, :current_state, :transition_to, :transition_to!,
           to: :state_machine
end
