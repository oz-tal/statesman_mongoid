# Statesman Mongoid

[![Gem Version](https://badge.fury.io/rb/statesman_mongoid.svg)](https://badge.fury.io/rb/statesman_mongoid)
[![Build](https://github.com/oz-tal/statesman_mongoid/workflows/Ruby/badge.svg)](https://github.com/oz-tal/statesman_mongoid/actions)
[![Maintainability](https://api.codeclimate.com/v1/badges/e9d5dfd27f76acc8fa3a/maintainability)](https://codeclimate.com/github/oz-tal/statesman_mongoid/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/e9d5dfd27f76acc8fa3a/test_coverage)](https://codeclimate.com/github/oz-tal/statesman_mongoid/test_coverage)

Set of adapters to use [Mongoid](https://github.com/mongodb/mongoid) as the persistence layer for [Statesman](https://github.com/gocardless/statesman). Provide feature parity with default adapters, generators and specs in an hassle-free manner.

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
``` ruby
Statesman::Adapters::Mongoid
Statesman::Adapters::MongoidTransition
Statesman::Adapters::MongoidQueries
```

Generator(s) specific to mongoid:
```
rails generate statesman:mongoid_transition Order OrderTransition
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/oz-tal/statesman_mongoid.

## known issues

Transactions in Mongoid 8.x (and under) lack support for `after_commit` callbacks and `Mongoid::Errors::Rollback` raising. This could affect transactional integrity in some situation. Since the required features are present in Mongoid 9.0.0-alpha, a fix is planned after the new major version rollout of the alpha phase.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
