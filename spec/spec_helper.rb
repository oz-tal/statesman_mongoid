# frozen_string_literal: true

# Test coverage metrics
require 'simplecov'
SimpleCov.start

require "statesman"
# We have to include all of Rails to make rspec-rails work
require "rails"
require "action_view"
require "action_dispatch"
require "action_controller"
require "rspec/rails"
require "support/mongoid"
require "rspec/its"
require "pry"

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }

  config.order = "random"

  def connection_failure
    Moped::Errors::ConnectionFailure if defined?(Moped)
  end

  if config.exclusion_filter[:mongo]
    puts "Skipping Mongo tests"
  else
    require "mongoid"

    # Try a mongo connection at the start of the suite and raise if it fails
    begin
      Mongoid.configure do |mongo_config|
        if defined?(Moped)
          mongo_config.connect_to("statesman_test")
          mongo_config.sessions["default"]["options"]["max_retries"] = 2
        else
          mongo_config.connect_to("statesman_test", server_selection_timeout: 2)
        end
      end
      # Attempting a mongo operation will trigger 2 retries then throw an
      # exception if mongo is not running.
      Mongoid.purge!
    rescue connection_failure => error
      puts "The spec suite requires MongoDB to be installed and running locally"
      puts "Mongo dependent specs can be filtered with rspec --tag '~mongo'"
      raise(error)
    end
  end

  config.before(:each, mongo: true) do
    Mongoid.purge!
  end
end
