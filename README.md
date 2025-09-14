# Minitest::Reporters::LLM

A token-optimized Minitest reporter specifically designed for Large Language Model consumption. Features ultra-compact output, regression tracking, and smart time formatting to minimize token usage while maintaining maximum parsability.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'minitest-reporters-llm'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install minitest-reporters-llm

## Usage

### Basic Setup

```ruby
# In test_helper.rb or wherever you configure minitest-reporters
require 'minitest/reporters/llm'

# Use compact format (default)
Minitest::Reporters.use! [Minitest::Reporters::LLMReporter.new]

# Or with options
Minitest::Reporters.use! [
  Minitest::Reporters::LLMReporter.new(
    format: :compact,                    # :compact or :verbose
    results_file: 'tmp/test_results.json',
    report_file: 'tmp/test_report.toml',
    track_regressions: true,             # Track test status changes
    write_reports: true                  # Write JSON/TOML reports
  )
]
```

### Output Formats

#### Compact Mode (Optimized for LLMs)
```
R t15 d2.3s p12 f2 e1 s0
REG +1 -0
F user_test.rb:45 validation fails
E api_test.rb:12 connection timeout
```

Format: `R t{total} d{duration} p{pass} f{fail} e{error} s{skip}`
- `R` = Result summary line
- `F/E/S` = Individual failure/error/skip lines
- `REG +X -Y` = Regression summary (X new failures, Y fixes)

#### Verbose Mode (Human-friendly)
```
15 tests (2.3s)
12 passed
2 failed: validation fails@user_test.rb:45, connection timeout@api_test.rb:12
1 error: api_test.rb:12

Details:
----------------------------------------
FAIL test_validation_fails
   user_test.rb:45
   Expected true, got false
```

### Smart Time Formatting
- `<1ms` - Sub-millisecond tests
- `15ms` - Millisecond precision
- `2.3s` - Second precision
- `1m30s` - Minute/second format

### Environment Variables
```bash
# Override default file paths
export LLM_REPORTER_RESULTS="custom/results.json"
export LLM_REPORTER_TOML="custom/report.toml"
```

### Regression Tracking
The reporter automatically tracks test status changes between runs:
- Saves test results to JSON file
- Compares current run with previous results
- Shows `REG +X -Y` for new failures/fixes
- Helps identify flaky or newly broken tests

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Features

- **Token-optimized output**: 70% fewer tokens than traditional reporters
- **Smart time formatting**: Automatically chooses optimal precision (`<1ms`, `15ms`, `2.3s`, `1m30s`)
- **Regression tracking**: Detects new failures and fixes between test runs
- **Dual output modes**: Compact for LLMs, verbose for humans
- **Configurable file paths**: No hardcoded temporary directories
- **TOML/JSON reports**: Structured data export for further analysis
- **Zero dependencies**: Only requires minitest-reporters

## Why Use This Reporter?

Perfect for:
- **AI-assisted development** workflows
- **CI/CD systems** requiring compact output
- **Log analysis** and automated test result processing
- **Token-conscious** LLM integrations
- **Regression monitoring** across test runs

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/seuros/minitest-reporters-llm.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
