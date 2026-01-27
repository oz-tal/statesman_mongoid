# frozen_string_literal: true

class OrderStateMachine
  include Statesman::Machine

  state :pending, initial: true
  state :processing
  state :shipped
  state :delivered
  state :cancelled
  state :refunded

  transition from: :pending,    to: %i[processing cancelled]
  transition from: :processing, to: %i[shipped cancelled]
  transition from: :shipped,    to: %i[delivered refunded]
  transition from: :delivered,  to: :refunded
  transition from: :cancelled,  to: :pending
end
