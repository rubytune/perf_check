require 'perf_check'
require 'pry'

Dir.glob(File.expand_path('support/*.rb', __dir__)).each do |file|
  require file
end

RSpec.configure do |config|
  config.include Support::Apps
  config.include Support::Commands
  config.include Support::Paths

  config.after(:suite) do
    FileUtils.rm_rf(Support::Apps.minimal_app_dir)
  end

  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4, it's included here for
    # forward compatibility.
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
