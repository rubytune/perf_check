require 'net/http'
require 'digest'
require 'fileutils'
require 'benchmark'
require 'ostruct'
require 'colorize'
require 'json'

class PerfCheck
  attr_accessor :options, :server, :test_cases

  def self.app_root
    @app_root ||= begin
      dir = Dir.pwd
      until dir == '/' || File.exist?("#{dir}/config/application.rb")
        dir = File.dirname(dir)
      end

      unless File.exist?("#{dir}/config/application.rb")
        abort("perf_check should be run from a rails directory")
      end

      dir
    end
  end

  def initialize
    self.options = OpenStruct.new
    self.server = Server.new
    self.test_cases = []
  end

  def add_test_case(route)
    test_cases.push(TestCase.new(route.sub(/^([^\/])/, '/\1')))
  end

  def run
    profile_requests

    if options.reference
      Git.stash_if_needed
      Git.checkout_reference(options.reference)
      test_cases.each{ |x| x.switch_to_reference_context }

      profile_requests
    end
  end

  private

  def profile_requests
    run_migrations_up if options.run_migrations?

    server.restart
    test_cases.each_with_index do |test, i|
      trigger_before_start_callbacks(test)
      server.restart unless i.zero? || options.diff

      test.cookie = options.cookie

      if options.diff
        logger.info("Issuing #{test.resource}")
      else
        logger.info ''
        logger.info("Benchmarking #{test.resource}:")
      end

      test.run(server, options)
    end
  ensure
    run_migrations_down if options.run_migrations?
  end

  def run_migrations_up
    Bundler.with_clean_env{ `bundle exec rake db:migrate` }
    Git.clean_db
  end

  def run_migrations_down
    Git.migrations_to_run_down.each do |version|
      Bundler.with_clean_env{ `bundle exec rake db:migrate:down VERSION=#{version}` }
    end
    Git.clean_db
  end
end

require 'perf_check/logger'
require 'perf_check/server'
require 'perf_check/test_case'
require 'perf_check/git'
require 'perf_check/config'
require 'perf_check/callbacks'
require 'perf_check/output'

if defined?(Rails) && ENV['PERF_CHECK']
  require 'perf_check/railtie'
end
