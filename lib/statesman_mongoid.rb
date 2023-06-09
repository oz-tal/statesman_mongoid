# frozen_string_literal: true

# require_relative "statesman_mongoid/version"
Dir[__dir__ + '/statesman/adapters/*'].each &method(:require)

module StatesmanMongoid
  class Error < StandardError; end
end
