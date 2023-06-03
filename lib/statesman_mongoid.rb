# frozen_string_literal: true

require_relative "statesman_mongoid/version"
require_relative "statesman/adapters/mongoid"
require_relative "statesman/adapters/mongoid_transition"

module StatesmanMongoid
  class Error < StandardError; end
end
