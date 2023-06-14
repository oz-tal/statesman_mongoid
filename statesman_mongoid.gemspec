# frozen_string_literal: true

require_relative "lib/statesman_mongoid/version"

Gem::Specification.new do |spec|
  spec.name = "statesman_mongoid"
  spec.version = StatesmanMongoid::VERSION
  spec.authors = ["oz-tal"]
  spec.email = ["979951+oz-tal@users.noreply.github.com"]

  spec.summary = "Mongoid adapters for Statesman"
  spec.homepage = "https://github.com/oz-tal/statesman_mongoid"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/oz-tal/statesman_mongoid"
  spec.metadata["changelog_uri"] = "https://github.com/oz-tal/statesman_mongoid"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "statesman", "~> 10.0"

  spec.add_development_dependency "ammeter", "~> 1.1"
  spec.add_development_dependency "gc_ruboconfig", "~> 3.6.0"
  spec.add_development_dependency "rails", ">= 5.2"
  spec.add_development_dependency "rake", "~> 13.0.0"
  spec.add_development_dependency "rspec", "~> 3.1"
  spec.add_development_dependency "rspec-github", "~> 2.4.0"
  spec.add_development_dependency "rspec-its", "~> 1.1"
  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "timecop", "~> 0.9.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
