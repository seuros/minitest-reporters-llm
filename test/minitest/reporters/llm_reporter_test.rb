# frozen_string_literal: true

require 'test_helper'
require 'stringio'

class LlmReporterIntegrationTest < Minitest::Test
  FakeFailure = Struct.new(:message)
  FakeResult = Struct.new(:klass, :name, :failure) do
    def passed?
      failure.nil?
    end

    def skipped?
      false
    end

    def error?
      false
    end

    def source_location
      [__FILE__, 1]
    end

    def assertions
      0
    end

    def time
      0.0
    end
  end

  def setup
    @results_file = File.expand_path('../../tmp/test_regression_results.json', __dir__)
    @toml_file    = File.expand_path('../../tmp/test_llm_report.toml', __dir__)
    ensure_clean_results_file
  end

  def teardown
    ensure_clean_results_file
  end

  def test_records_and_saves_results
    reporter = Minitest::Reporters::LLMReporter.new(
      results_file: @results_file,
      report_file: @toml_file
    )

    pass = FakeResult.new('SampleTest', 'test_ok', nil)
    fail = FakeResult.new('SampleTest', 'test_bad', FakeFailure.new('boom'))

    reporter.record(pass)
    reporter.record(fail)

    # Save explicitly without invoking full report flow
    reporter.send(:save_current_results)

    stored = JSON.parse(File.read(@results_file))
    assert_equal 'pass', stored['SampleTest#test_ok']
    assert_equal 'fail', stored['SampleTest#test_bad']
  end

  def test_compact_location_formatting
    reporter = Minitest::Reporters::LLMReporter.new(
      results_file: @results_file,
      report_file: @toml_file
    )
    res = FakeResult.new('SampleTest', 'test_the_title_renders', nil)
    formatted = reporter.send(:format_test_location, res)
    assert_match(/the title renders@.+:\d+/, formatted)
  end

  def test_writes_toml_summary
    reporter = Minitest::Reporters::LLMReporter.new(
      results_file: @results_file,
      report_file: @toml_file
    )
    reporter.start # initialize timing
    pass = FakeResult.new('SampleTest', 'test_ok', nil)
    fail = FakeResult.new('SampleTest', 'test_bad', FakeFailure.new('boom'))

    reporter.record(pass)
    reporter.record(fail)

    capture_io { reporter.report }

    assert File.exist?(@toml_file), 'Expected TOML report to exist'
    contents = File.read(@toml_file)
    assert_includes contents, '[summary]'
    assert_includes contents, 'tests = 2'
    assert_includes contents, 'failures = 1'
  end

  def test_format_environment_variable_compact
    with_env('LLM_REPORTER_FORMAT' => 'compact') do
      reporter = Minitest::Reporters::LLMReporter.new(
        results_file: @results_file,
        report_file: @toml_file
      )
      assert_equal :compact, reporter.instance_variable_get(:@options)[:format]
    end
  end

  def test_format_environment_variable_verbose
    with_env('LLM_REPORTER_FORMAT' => 'verbose') do
      reporter = Minitest::Reporters::LLMReporter.new(
        results_file: @results_file,
        report_file: @toml_file
      )
      assert_equal :verbose, reporter.instance_variable_get(:@options)[:format]
    end
  end

  def test_format_environment_variable_case_insensitive
    with_env('LLM_REPORTER_FORMAT' => 'VERBOSE') do
      reporter = Minitest::Reporters::LLMReporter.new(
        results_file: @results_file,
        report_file: @toml_file
      )
      assert_equal :verbose, reporter.instance_variable_get(:@options)[:format]
    end
  end

  def test_format_environment_variable_invalid_defaults_to_compact
    with_env('LLM_REPORTER_FORMAT' => 'invalid') do
      reporter = Minitest::Reporters::LLMReporter.new(
        results_file: @results_file,
        report_file: @toml_file
      )
      assert_equal :compact, reporter.instance_variable_get(:@options)[:format]
    end
  end

  def test_format_environment_variable_not_set_defaults_to_compact
    with_env('LLM_REPORTER_FORMAT' => nil) do
      reporter = Minitest::Reporters::LLMReporter.new(
        results_file: @results_file,
        report_file: @toml_file
      )
      assert_equal :compact, reporter.instance_variable_get(:@options)[:format]
    end
  end

  private

  def with_env(env_vars)
    old_values = {}
    env_vars.each do |key, value|
      old_values[key] = ENV.fetch(key, nil)
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    old_values.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end

  def ensure_clean_results_file
    FileUtils.rm_f(@results_file)
    File.delete(@toml_file) if defined?(@toml_file) && File.exist?(@toml_file)
    dir = File.dirname(@results_file)
    Dir.rmdir(dir) if Dir.exist?(dir) && Dir.empty?(dir)
  rescue StandardError
    # ignore cleanup errors in test env
  end
end
