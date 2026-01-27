# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'statesman'
require 'rails'
require 'action_view'
require 'action_dispatch'
require 'action_controller'
require 'rspec/rails'
require 'rspec/its'
require 'pry'

# Load the gem first so StatesmanMongoid module is available
require 'statesman_mongoid'

require 'support/mongoid'

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }

  config.order = 'random'

  if config.exclusion_filter[:mongo]
    puts 'Skipping Mongo tests'
  else
    require 'mongoid'

    begin
      Mongoid.configure do |mongo_config|
        mongo_config.connect_to('statesman_test', server_selection_timeout: 2)
      end
      Mongoid.purge!
    rescue Mongo::Error::NoServerAvailable => e
      puts 'The spec suite requires MongoDB to be installed and running locally'
      puts "Mongo dependent specs can be filtered with rspec --tag '~mongo'"
      raise(e)
    end
  end

  config.before(:each, mongo: true) do
    Mongoid.purge!
    StatesmanMongoid.reset!
  end
end
