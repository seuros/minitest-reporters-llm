# frozen_string_literal: true

require_relative 'lib/minitest/reporters/llm/version'

Gem::Specification.new do |spec|
  spec.name          = 'minitest-reporters-llm'
  spec.version       = Minitest::Reporters::LLM::VERSION
  spec.authors       = ['Abdelkader Boudih']
  spec.email         = ['terminale@gmail.com']

  spec.summary       = 'Token-optimized Minitest reporter for LLM consumption with regression tracking'
  spec.description   = 'A Minitest reporter optimized for Large Language Model consumption, featuring compact emoji-based output, regression detection by comparing test runs, TOML report generation, and detailed failure reporting with file locations. Perfect for AI-assisted development workflows.'
  spec.homepage      = 'https://github.com/seuros/minitest-reporters-llm'
  spec.license       = 'MIT'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => 'https://github.com/seuros/minitest-reporters-llm',
    'changelog_uri' => 'https://github.com/seuros/minitest-reporters-llm/blob/master/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/seuros/minitest-reporters-llm/issues',
    'rubygems_mfa_required' => 'true'
  }

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[
                          lib/**/*.rb
                          *.md
                          *.txt
                          *.gemspec
                          Rakefile
                          bin/*
                        ]).reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.3'

  spec.add_development_dependency 'bundler', '~> 2.5'
  spec.add_development_dependency 'rake', '~> 13.0'

  spec.add_dependency 'minitest', '>= 5.25'
  spec.add_dependency 'minitest-reporters', '>= 1.7.1'
end
