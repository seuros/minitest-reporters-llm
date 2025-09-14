# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'minitest/reporters/llm'

require 'minitest/autorun'
require 'minitest/reporters'

# Use the LLM reporter for this test suite
Minitest::Reporters.use! [Minitest::Reporters::LLMReporter.new]
