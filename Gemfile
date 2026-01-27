# frozen_string_literal: true

source "https://rubygems.org"

gemspec

if ENV['RAILS_VERSION'] == 'master'
  gem "rails", git: "https://github.com/rails/rails"
elsif ENV['RAILS_VERSION']
  gem "rails", "~> #{ENV['RAILS_VERSION']}"
end

if ENV['MONGOID_VERSION']
  gem "mongoid", "~> #{ENV['MONGOID_VERSION']}"
end

if ENV['STATESMAN_VERSION']
  gem "statesman", "~> #{ENV['STATESMAN_VERSION']}"
end

group :development do
  gem "pry"
end

group :test do
  gem 'simplecov', require: false
  # Required as separate gem in Ruby 3.4+
  gem 'base64'
  gem 'bigdecimal'
  gem 'mutex_m'
  gem 'drb'
end
