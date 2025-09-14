# frozen_string_literal: true

require 'test_helper'

class Minitest::Reporters::LLMTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Minitest::Reporters::LLM::VERSION
  end

  def test_it_loads
    assert defined?(::Minitest::Reporters::LLMReporter)
  end
end
