# frozen_string_literal: true

require_relative 'statesman_mongoid/version'

# StatesmanMongoid provides MongoDB/Mongoid adapters for the Statesman state machine library.
#
# It detects runtime capabilities and provides appropriate transaction support:
# - Mongoid 9+ with replica set: Full ACID transactions with proper after_commit timing
# - Mongoid 8.x or standalone: Session-only fallback mode
module StatesmanMongoid
  class Error < StandardError; end

  class << self
    # Check if Mongoid 9+ transaction API is available
    def mongoid_9_or_higher?
      return @mongoid_9_or_higher if defined?(@mongoid_9_or_higher)

      @mongoid_9_or_higher = Gem::Version.new(Mongoid::VERSION) >= Gem::Version.new('9.0')
    end

    # Check if connected to a replica set (required for transactions)
    def replica_set?
      topology = Mongoid.default_client.cluster.topology
      topology.class.name.include?('ReplicaSet')
    rescue StandardError
      false
    end

    # Check if full transaction support is available
    # Requires both Mongoid 9+ AND a replica set connection
    def transactions_available?
      mongoid_9_or_higher? && replica_set?
    end

    # Reset memoized values (useful for testing)
    def reset!
      remove_instance_variable(:@mongoid_9_or_higher) if defined?(@mongoid_9_or_higher)
    end
  end
end

# Load adapters
Dir[File.join(__dir__, 'statesman/adapters/*')].sort.each { |f| require f }
