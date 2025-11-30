# frozen_string_literal: true

require 'test_helper'
require 'stringio'

class LlmReporterIntegrationTest < Minitest::Test
  FakeFailure = Struct.new(:message)
  class FakeResult
    attr_reader :klass, :name, :failure

    def initialize(klass:, name:, failure: nil, skipped: false, errored: false, location: [__FILE__, 1])
      @klass = klass
      @name = name
      @failure = failure
      @skipped = skipped
      @errored = errored
      @location = location
    end

    def passed?
      !@skipped && !@errored && failure.nil?
    end

    def skipped?
      @skipped
    end

    def error?
      @errored
    end

    def source_location
      @location
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
      report_file: @toml_file,
      io: StringIO.new
    )

    pass = FakeResult.new(klass: 'SampleTest', name: 'test_ok')
    fail = FakeResult.new(klass: 'SampleTest', name: 'test_bad', failure: FakeFailure.new('boom'))

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
      report_file: @toml_file,
      io: StringIO.new
    )
    res = FakeResult.new(klass: 'SampleTest', name: 'test_the_title_renders')
    formatted = reporter.send(:format_test_location, res)
    assert_match(/the title renders@.+:\d+/, formatted)
  end

  def test_writes_toml_summary
    reporter = Minitest::Reporters::LLMReporter.new(
      results_file: @results_file,
      report_file: @toml_file,
      io: StringIO.new
    )
    reporter.start # initialize timing
    pass = FakeResult.new(klass: 'SampleTest', name: 'test_ok')
    fail = FakeResult.new(klass: 'SampleTest', name: 'test_bad', failure: FakeFailure.new('boom'))

    reporter.record(pass)
    reporter.record(fail)

    capture_io { reporter.report }

    assert File.exist?(@toml_file), 'Expected TOML report to exist'
    contents = File.read(@toml_file)
    assert_includes contents, '[summary]'
    assert_includes contents, 'tests = 2'
    assert_includes contents, 'failures = 1'
  end

  def test_records_all_statuses
    reporter = Minitest::Reporters::LLMReporter.new(
      results_file: @results_file,
      report_file: @toml_file,
      io: StringIO.new
    )

    pass = FakeResult.new(klass: 'SampleTest', name: 'test_ok')
    skip = FakeResult.new(klass: 'SampleTest', name: 'test_skip', skipped: true, failure: FakeFailure.new('skip'))
    error = FakeResult.new(klass: 'SampleTest', name: 'test_error', errored: true, failure: FakeFailure.new('boom'))

    reporter.record(pass)
    reporter.record(skip)
    reporter.record(error)

    reporter.send(:save_current_results)

    stored = JSON.parse(File.read(@results_file))
    assert_equal 'pass', stored['SampleTest#test_ok']
    assert_equal 'skip', stored['SampleTest#test_skip']
    assert_equal 'error', stored['SampleTest#test_error']
  end

  def test_regression_tracking_counts_errors_and_fixes
    io = StringIO.new
    reporter = Minitest::Reporters::LLMReporter.new(
      results_file: @results_file,
      report_file: @toml_file,
      io: io
    )

    reporter.instance_variable_set(:@previous_results, {
                                  'SampleTest#test_ok' => 'pass',
                                  'SampleTest#test_fix' => 'fail',
                                  'SampleTest#test_skip' => 'skip'
                                })

    reporter.instance_variable_set(:@current_results, {
                                  'SampleTest#test_ok' => 'error',
                                  'SampleTest#test_fix' => 'pass',
                                  'SampleTest#test_skip' => 'pass'
                                })

    reporter.send(:show_regressions_compact)
    assert_includes io.string, 'REG +1 -2'
  end

  def test_toml_arrays_are_valid
    reporter = Minitest::Reporters::LLMReporter.new(
      results_file: @results_file,
      report_file: @toml_file,
      io: StringIO.new
    )

    toml = reporter.send(
      :build_toml,
      details: { failed: %w[foo bar], errors: [], skipped: [] }
    )

    assert_includes toml, 'failed = ["foo", "bar"]'
    assert_includes toml, 'errors = []'
  end

  def test_errors_not_duplicated_in_details
    io = StringIO.new
    reporter = Minitest::Reporters::LLMReporter.new(
      results_file: @results_file,
      report_file: @toml_file,
      format: :verbose,
      io: io
    )

    reporter.start
    error = FakeResult.new(klass: 'SampleTest', name: 'test_boom', errored: true, failure: FakeFailure.new('boom'))
    reporter.record(error)

    reporter.report

    refute_includes io.string, '❌ test_boom'
    assert_includes io.string, '💥 1:'
    assert_includes io.string, '💥 test_boom'
  end

  def test_format_environment_variable_compact
    with_env('LLM_REPORTER_FORMAT' => 'compact') do
      reporter = Minitest::Reporters::LLMReporter.new(
        results_file: @results_file,
        report_file: @toml_file,
        io: StringIO.new
      )
      assert_equal :compact, reporter.instance_variable_get(:@options)[:format]
    end
  end

  def test_format_environment_variable_verbose
    with_env('LLM_REPORTER_FORMAT' => 'verbose') do
      reporter = Minitest::Reporters::LLMReporter.new(
        results_file: @results_file,
        report_file: @toml_file,
        io: StringIO.new
      )
      assert_equal :verbose, reporter.instance_variable_get(:@options)[:format]
    end
  end

  def test_format_environment_variable_case_insensitive
    with_env('LLM_REPORTER_FORMAT' => 'VERBOSE') do
      reporter = Minitest::Reporters::LLMReporter.new(
        results_file: @results_file,
        report_file: @toml_file,
        io: StringIO.new
      )
      assert_equal :verbose, reporter.instance_variable_get(:@options)[:format]
    end
  end

  def test_format_environment_variable_invalid_defaults_to_compact
    with_env('LLM_REPORTER_FORMAT' => 'invalid') do
      reporter = Minitest::Reporters::LLMReporter.new(
        results_file: @results_file,
        report_file: @toml_file,
        io: StringIO.new
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
