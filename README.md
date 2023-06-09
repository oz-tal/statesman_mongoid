# Statesman Mongoid

Restored mongoid adapters for [Statesman](https://github.com/gocardless/statesman).

TODO: Restore generators and test units

NOTE: This is an early salvage of the dropped mongoid support with a refitted queries adapter, a couple of fixes and some manual testing, use at your own risk and feel free to contribute.

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

TODO: Expand usage instructions 

Follow instructions in the Statesman's doc and replace invoked classes with these ones when approriate:
``` ruby
Statesman::Adapters::Mongoid
Statesman::Adapters::MongoidTransition
Statesman::Adapters::MongoidQueries
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/oz-tal/statesman_mongoid.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
