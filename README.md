# Statesman Mongoid

[![Gem Version](https://badge.fury.io/rb/statesman_mongoid.svg)](https://badge.fury.io/rb/statesman_mongoid)
[![Build](https://github.com/oz-tal/statesman_mongoid/workflows/Ruby/badge.svg)](https://github.com/oz-tal/statesman_mongoid/actions)
[![Maintainability](https://api.codeclimate.com/v1/badges/e9d5dfd27f76acc8fa3a/maintainability)](https://codeclimate.com/github/oz-tal/statesman_mongoid/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/e9d5dfd27f76acc8fa3a/test_coverage)](https://codeclimate.com/github/oz-tal/statesman_mongoid/test_coverage)

Set of adapters to use [Mongoid](https://github.com/mongodb/mongoid) as the persistence layer for [Statesman](https://github.com/gocardless/statesman). Provides feature parity with default adapters, generators and specs in a hassle-free manner.

## Version Compatibility

| statesman_mongoid | Ruby     | Mongoid   | Statesman | MongoDB  |
|-------------------|----------|-----------|-----------|----------|
| 0.6.x             | >= 2.7   | 8.0 - 9.x | 10.0 - 13.x | 5.0 - 7.0 |
| 0.5.x             | >= 2.7   | ~> 8.0    | ~> 10.0   | 4.x - 5.x |

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'statesman_mongoid'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install statesman_mongoid

## Usage

Follow instructions in the Statesman's doc and simply replace the ActiveRecord adapters with these ones when appropriate:

```ruby
Statesman::Adapters::Mongoid
Statesman::Adapters::MongoidTransition
Statesman::Adapters::MongoidQueries
```

Generator(s) specific to mongoid:

```
rails generate statesman:mongoid_transition Order OrderTransition
```

### Transition Model

Your transition model should include the following fields:

```ruby
class OrderTransition
  include Mongoid::Document
  include Mongoid::Timestamps

  field :to_state, type: String
  field :from_state, type: String        # Optional (Statesman 13.1+)
  field :sort_key, type: Integer
  field :most_recent, type: Boolean      # Optional (enables optimization)
  field :statesman_metadata, type: Hash

  index(sort_key: 1)
  # Required for most_recent optimization with transactions
  index({ order_id: 1, most_recent: 1 }, unique: true, sparse: true)

  belongs_to :order, index: true

  include Statesman::Adapters::MongoidTransition
end
```

## Transaction Support (Mongoid 9+)

With Mongoid 9.0+ and a MongoDB replica set, the adapter provides full transaction support:

- **Atomic transitions**: All changes within a transition are committed together
- **Proper `after_commit` timing**: Callbacks fire only after successful commit
- **Rollback on errors**: Failed transitions don't leave partial state
- **`most_recent` optimization**: Automatic flag for faster "current state" queries

### Requirements for Transaction Support

1. **Mongoid 9.0 or higher**
2. **MongoDB replica set** (required for multi-document transactions)

You can check if transactions are available at runtime:

```ruby
StatesmanMongoid.transactions_available?  # => true/false
StatesmanMongoid.mongoid_9_or_higher?     # => true/false
StatesmanMongoid.replica_set?             # => true/false
```

### Fallback Mode (Mongoid 8.x or Standalone MongoDB)

When transactions aren't available, the adapter falls back to session-only mode:
- Transitions still work correctly
- `after_commit` fires immediately after save (not deferred)
- `most_recent` optimization is disabled to avoid non-atomic updates

### Setting Up a Local Replica Set

For development, you can run MongoDB as a single-node replica set:

```bash
# Start MongoDB with replica set enabled
mongod --replSet rs0

# Initialize the replica set (one-time setup)
mongosh --eval "rs.initiate()"
```

Or using Docker:

```yaml
# docker-compose.yml
services:
  mongodb:
    image: mongo:7.0
    command: mongod --replSet rs0
    ports:
      - "27017:27017"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Running Tests

The test suite requires MongoDB to be running locally:

```bash
# Run all tests
bundle exec rspec

# Run with specific Mongoid version
MONGOID_VERSION=9.0 bundle install && bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/oz-tal/statesman_mongoid.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
