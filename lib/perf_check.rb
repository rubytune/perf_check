require 'net/http'
require 'digest'
require 'fileutils'
require 'benchmark'
require 'ostruct'
require 'colorize'
require 'json'
require 'logger'

class PerfCheck
  attr_reader :app_root, :options, :git, :server, :test_cases
  attr_accessor :logger

  def initialize(app_root)
    @app_root = app_root

    @options = OpenStruct.new(
      number_of_requests: 20,
      reference: 'master',
      cookie: nil,
      headers: {},
      http_statuses: [200],
      verify_responses: false,
      caching: true,
      json: false
    )

    @logger = Logger.new(STDERR).tap do |logger|
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime}] #{sprintf('%5s', severity)} --: #{msg}\n"
      end
    end

    @git = Git.new(self)
    @server = Server.new(self)
    @test_cases = []
  end

  def load_config
    if File.exists?("#{app_root}/config/perf_check.rb")
      this = self
      Kernel.send(:define_method, :perf_check){ this }
      require "#{app_root}/config/perf_check"
      Kernel.send(:remove_method, :perf_check)
    end
  end

  def add_test_case(route)
    test_cases.push(TestCase.new(self, route.sub(/^([^\/])/, '/\1')))
  end

  def run
    begin
      profile_requests

      if options.reference
        git.stash_if_needed
        git.checkout_reference(options.reference)
        test_cases.each{ |x| x.switch_to_reference_context }

        profile_requests
      end
    ensure
      server.exit rescue nil
      if options.reference
        git.checkout_current_branch(false) rescue nil
        (git.pop rescue nil) if git.stashed?
      end
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
    Bundler.with_clean_env{ puts `bundle exec rake db:migrate` }
    git.clean_db
  end

  def run_migrations_down
    git.migrations_to_run_down.each do |version|
      Bundler.with_clean_env{ puts `bundle exec rake db:migrate:down VERSION=#{version}` }
    end
    git.clean_db
  end
end

require 'perf_check/server'
require 'perf_check/test_case'
require 'perf_check/git'
require 'perf_check/config'
require 'perf_check/callbacks'
require 'perf_check/output'

if defined?(Rails) && ENV['PERF_CHECK']
  require 'perf_check/railtie'
end
