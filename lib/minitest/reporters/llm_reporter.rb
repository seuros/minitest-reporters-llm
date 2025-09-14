# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'minitest/reporters/llm/version'

module Minitest
  module Reporters
    class LLMReporter < ::Minitest::Reporters::BaseReporter
      VERSION = LLM::VERSION

      def initialize(options = {})
        super
        @options = default_options.merge(options)
        @results_file = @options[:results_file]
        @report_file = @options[:report_file]
        @previous_results = @options[:track_regressions] ? load_previous_results : {}
        @current_results = {}
        @llm_start_time = nil
      end

      def start(*args)
        super
        @llm_start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def record(result)
        super
        test_key = "#{result.klass}##{result.name}"
        @current_results[test_key] = result.passed? ? 'pass' : 'fail'
      end

      def report
        total = @current_results.size
        fails_ct  = tests_list.count { |t| t.failure && !t.skipped? && !t.error? }
        errors_ct = tests_list.count { |t| t.failure && t.error? }
        skips_ct  = tests_list.count(&:skipped?)
        passes = total - fails_ct - errors_ct - skips_ct

        if @options[:format] == :compact
          report_compact(total, passes, fails_ct, errors_ct, skips_ct)
        else
          report_verbose(total, passes, fails_ct, errors_ct, skips_ct)
        end

        save_current_results if @options[:track_regressions]
        write_toml_summary
      end

      def report_compact(total, passes, fails_ct, errors_ct, skips_ct)
        puts "R t#{total} d#{format_time(llm_total_time)} p#{passes} f#{fails_ct} e#{errors_ct} s#{skips_ct}"

        show_regressions_compact

        # Show failures
        if fails_ct.positive?
          tests_list.select { |t| t.failure && !t.skipped? && !t.error? }.each do |test|
            puts "F #{format_test_location_compact(test)}"
          end
        end

        # Show errors
        if errors_ct.positive?
          tests_list.select { |t| t.failure && t.error? }.each do |test|
            puts "E #{format_test_location_compact(test)}"
          end
        end

        # Show skips
        return unless skips_ct.positive?

        tests_list.select(&:skipped?).each do |test|
          puts "S #{format_test_location_compact(test)}"
        end
      end

      def report_verbose(total, passes, fails_ct, errors_ct, skips_ct)
        puts
        puts "🏃 #{total} tests (#{format_time(llm_total_time)})"
        puts "✅ #{passes}" if passes.positive?

        show_regressions

        if fails_ct.positive?
          failed_tests = tests_list.select { |t| t.failure && !t.skipped? && !t.error? }
                                   .map { |test| format_test_location(test) }
          puts "❌ #{failed_tests.size} failed: #{failed_tests.join(', ')}" if failed_tests.any?
        end

        if errors_ct.positive?
          error_tests = tests_list.select { |t| t.failure && t.error? }
                                  .map { |test| format_test_location(test) }
          puts "💥 #{errors_ct}: #{error_tests.join(', ')}"
        end

        if skips_ct.positive?
          skip_tests = tests_list.select(&:skipped?)
          puts "⏭️  #{skips_ct} skipped:"
          skip_tests.each do |test|
            msg = clean_message(test.failure&.message)
            puts "    - #{format_test_location(test)}: #{msg}"
          end
        end

        show_failure_details if fails_ct.positive? || errors_ct.positive?
      end

      private

      def default_options
        {
          results_file: ENV.fetch('LLM_REPORTER_RESULTS', 'tmp/test_results.json'),
          report_file: ENV.fetch('LLM_REPORTER_TOML', 'tmp/test_report.toml'),
          format: :compact,
          track_regressions: true,
          write_reports: true
        }
      end

      def format_time(time)
        return '0' unless time.is_a?(Numeric)
        return '<1ms' if time < 0.001

        if time < 1
          ms = (time * 1000).round
          "#{ms}ms"
        elsif time < 60
          "#{time.round(1)}s"
        else
          minutes = (time / 60).floor
          seconds = (time % 60).round
          "#{minutes}m#{seconds}s"
        end
      end

      def llm_total_time
        return nil unless @llm_start_time

        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        now - @llm_start_time
      rescue StandardError
        nil
      end

      def format_test_location(test)
        test_name = (test.name || '').to_s.gsub(/^test_/, '').tr('_', ' ')
        if (loc = source_location_for(test)) && loc[0] && loc[1]
          file = File.basename(loc[0])
          line = loc[1]
          "#{test_name}@#{file}:#{line}"
        else
          test_name
        end
      end

      def format_test_location_compact(test)
        test_name = (test.name || '').to_s.gsub(/^test_/, '').tr('_', ' ')
        if (loc = source_location_for(test)) && loc[0] && loc[1]
          file = File.basename(loc[0])
          line = loc[1]
          "#{file}:#{line} #{test_name}"
        else
          test_name
        end
      end

      def source_location_for(test)
        # Try provided API first
        return test.source_location if test.respond_to?(:source_location)

        # Derive from class + method if possible
        begin
          klass_name = test.respond_to?(:klass) ? test.klass : test.class.name
          method_name = test.name
          return nil unless klass_name && method_name

          klass = constantize(klass_name)
          return nil unless klass&.instance_methods&.include?(method_name.to_sym)

          klass.instance_method(method_name).source_location
        rescue StandardError
          nil
        end
      end

      def constantize(name)
        names = name.split('::')
        names.shift if names.first.empty?
        names.inject(Object) { |constant, n| constant.const_get(n) }
      rescue NameError
        nil
      end

      def show_failure_details
        failed_tests = tests_list.select { |t| t.failure && !t.skipped? }
        error_tests = tests_list.select { |t| t.failure && t.error? }

        return unless failed_tests.any? || error_tests.any?

        puts
        puts '📋 Details:'
        puts '-' * 40

        failed_tests.each do |test|
          puts "❌ #{test.name}"
          puts "   #{format_location(test)}"
          puts "   #{clean_message(test.failure&.message)}"
          puts
        end

        error_tests.each do |test|
          puts "💥 #{test.name}"
          puts "   #{format_location(test)}"
          puts "   #{clean_message(test.failure&.message)}"
          puts
        end
      end

      def format_location(test)
        loc = source_location_for(test)
        if loc && loc[0] && loc[1]
          file = File.basename(loc[0])
          "#{file}:#{loc[1]}"
        else
          'unknown location'
        end
      end

      def clean_message(message)
        return 'No message' unless message

        message.to_s.split("\n").first&.strip || 'Unknown error'
      end

      def load_previous_results
        return {} unless File.exist?(@results_file)

        JSON.parse(File.read(@results_file))
      rescue JSON::ParserError, Errno::ENOENT
        {}
      end

      def save_current_results
        return unless @options[:write_reports]

        FileUtils.mkdir_p(File.dirname(@results_file))
        File.write(@results_file, JSON.pretty_generate(@current_results))
      rescue StandardError => e
        puts "Warning: Could not save regression results: #{e.message}" if ENV['DEBUG']
      end

      def show_regressions
        return if @previous_results.empty?

        new_failures = []
        fixes = []

        @current_results.each do |test_key, status|
          previous_status = @previous_results[test_key]

          if previous_status == 'pass' && status == 'fail'
            new_failures << test_key_to_location(test_key)
          elsif previous_status == 'fail' && status == 'pass'
            fixes << test_key_to_location(test_key)
          end
        end

        puts "✅➡️❌ #{new_failures.size}: #{new_failures.join(', ')}" if new_failures.any?
        puts "🎉 #{fixes.size}: #{fixes.join(', ')}" if fixes.any?
      end

      def show_regressions_compact
        return if @previous_results.empty?

        new_failures = 0
        fixes = 0

        @current_results.each do |test_key, status|
          previous_status = @previous_results[test_key]
          new_failures += 1 if previous_status == 'pass' && status == 'fail'
          fixes += 1 if previous_status == 'fail' && status == 'pass'
        end

        puts "REG +#{new_failures} -#{fixes}" if new_failures.positive? || fixes.positive?
      end

      def test_key_to_location(test_key)
        class_name, method_name = test_key.split('#', 2)
        method_name = method_name.to_s.gsub(/^test_/, '').tr('_', ' ')
        "#{method_name}@#{class_name}"
      end

      def write_toml_summary
        return unless @options[:write_reports]

        data = {
          summary: {
            tests: @current_results.size,
            passes: (@current_results.size - tests_list.count do |t|
              t.failure && !t.skipped? && !t.error?
            end - tests_list.count do |t|
                    t.failure && t.error?
                  end - tests_list.count(&:skipped?)),
            failures: tests_list.count { |t| t.failure && !t.skipped? && !t.error? },
            errors: tests_list.count { |t| t.failure && t.error? },
            skips: tests_list.count(&:skipped?),
            time_s: safe_total_time
          },
          details: {
            failed: tests_list.select { |t| t.failure && !t.skipped? && !t.error? }
                              .map { |t| format_test_location(t) },
            errors: tests_list.select { |t| t.failure && t.error? }
                              .map { |t| format_test_location(t) },
            skipped: tests_list.select(&:skipped?)
                               .map do |t|
              msg = clean_message(t.failure&.message)
              "#{format_test_location(t)}: #{msg}"
            end
          }
        }

        unless @previous_results.empty?
          new_failures = []
          fixes = []
          @current_results.each do |k, status|
            prev = @previous_results[k]
            new_failures << test_key_to_location(k) if prev == 'pass' && status == 'fail'
            fixes << test_key_to_location(k) if prev == 'fail' && status == 'pass'
          end
          data[:regressions] = { new_failures: new_failures, fixes: fixes }
        end

        toml = build_toml(data)
        FileUtils.mkdir_p(File.dirname(@report_file))
        File.write(@report_file, toml)
      rescue StandardError => e
        puts "Warning: Could not write TOML report: #{e.message}" if ENV['DEBUG']
      end

      def n(value)
        value.to_i
      end

      def tests_list
        tests || []
      end

      def safe_total_time
        t = llm_total_time
        t.is_a?(Numeric) ? t.to_f : 0.0
      end

      def build_toml(hash)
        lines = []
        hash.each do |section, values|
          lines << "[#{section}]"
          values.each do |k, v|
            key = k.to_s
            case v
            when Array
              escaped = v.map { |s| s.to_s.gsub('\\', '\\\\').gsub('"', '\\"') }
              lines << "#{key} = [\"#{escaped.join('\", \"')}\"]"
            when String
              val = v.to_s.gsub('\\', '\\\\').gsub('"', '\\"')
              lines << "#{key} = \"#{val}\""
            when Numeric
              lines << "#{key} = #{v}"
            when TrueClass, FalseClass
              lines << "#{key} = #{v}"
            else
              # Fallback to string
              val = v.to_s.gsub('\\', '\\\\').gsub('"', '\\"')
              lines << "#{key} = \"#{val}\""
            end
          end
          lines << ''
        end
        lines.join("\n")
      end
    end
  end
end
