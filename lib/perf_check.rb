require 'benchmark'
require 'bundler'
require 'colorize'
require 'digest'
require 'fileutils'
require 'logger'
require 'net/http'
require 'open3'
require 'ostruct'

class PerfCheck
  class Exception < ::Exception; end
  class ConfigLoadError < Exception; end
  class BundleError < Exception; end

  attr_reader :app_root, :options, :git, :server, :test_cases
  attr_accessor :logger

  def initialize(app_root)
    @app_root = File.expand_path(app_root)
    @options = OpenStruct.new(
      number_of_requests: 20,
      reference: 'master',
      branch: nil,
      cookie: nil,
      headers: {},
      http_statuses: [200],
      verify_no_diff: false,
      diff: false,
      diff_options: [
        '-U3',
        '--ignore-matching-lines=/mini-profiler-resources/includes.js'
      ],
      brief: false,
      caching: true,
      json: false,
      # Deployment is set to true when PerfCheck runs in a CI-like managed
      # environment.
      deployment: false,
      hard_reset: false,
      spawn_shell: false,
      environment: 'development',
      verbose: false
    )
    @git = Git.new(self)
    @server = Server.new(self)
    @test_cases = []
  end

  def logger
    @logger ||= Logger.new(
      STDERR,
      level: logger_level,
      formatter: logger_formatter
    )
  end

  def config_path
    File.join(app_root, 'config', 'perf_check.rb')
  end

  def load_config
    if File.exist?(config_path)
      config = File.read(config_path)
      perf_check = self
      eval(config, binding, config_path)
      true
    else
      false
    end
  end

  def add_test_case(request_path)
    test_cases.push(TestCase.new(self, request_path))
  end

  def run
    in_app_root do
      if options.compare_paths?
        compare_paths
      else
        compare_branches
      end
    end
  ensure
    cleanup_and_report
  end

  private

  def logger_level
    options.verbose ? Logger::DEBUG : Logger::INFO
  end

  def logger_formatter
    if options.verbose
      proc do |level, datetime, _, msg|
        "[#{datetime.strftime("%Y-%m-%d %H:%M:%S")}] (#{level}) #{msg}\n"
      end
    else
      proc do |_, datetime, _, msg|
        "[#{datetime.strftime("%Y-%m-%d %H:%M:%S")}] #{msg}\n"
      end
    end
  end

  def in_app_root(&block)
    if Dir.pwd != app_root
      Dir.chdir(app_root, &block)
    else
      block.call
    end
  end

  def compare_paths
    raise "Must have two paths" if test_cases.count != 2
    profile_compare_paths_requests
  end

  def compare_branches
    profile_requests
    if options.reference
      git.stash_if_needed
      git.checkout(options.reference, bundle_after_checkout: true, hard_reset: options.hard_reset)
      test_cases.each(&:switch_to_reference_context)
      profile_requests
    end
  end

  def profile_compare_paths_requests
    first = test_cases[0]
    reference_test = test_cases[1]
    profile_test_case(first)
    reference_test.switch_to_reference_context
    self.class.bundle
    profile_test_case(reference_test)
  end

  def profile_test_case(test)
    trigger_before_start_callbacks(test)
    run_migrations_up if options.run_migrations?
    logger.debug(server.restart)

    test.cookie = options.cookie

    if options.diff
      logger.info("Issuing #{test.resource}")
    else
      logger.info ''
      logger.info("Benchmarking #{test.resource}:")
    end

    test.run(server, options)
  ensure
    run_migrations_down if options.run_migrations?
  end

  def profile_requests
    test_cases.each do |test|
      profile_test_case(test)
    end
  end

  def run_migrations_up
    logger.info "Running db:migrate"
    Bundler.with_original_env do
      logger.info `cd #{app_root} && bundle exec rake db:migrate`
    end
    git.clean_db
  end

  def run_migrations_down
    Bundler.with_original_env do
      git.migrations_to_run_down.each do |version|
        logger.info "Running db:migrate:down VERSION=#{version}"
        logger.info `cd #{app_root} && bundle exec rake db:migrate:down VERSION=#{version}`
      end
    end
    git.clean_db
  end

  def cleanup_and_report
    server.exit
    if options.reference
      git.checkout(git.current_branch, bundle_after_checkout: true)
      git.pop if git.stashed?
    end

    callbacks = {}

    if $!
      callbacks[:error_message] = "#{$!.class}: #{$!.message}\n"
      callbacks[:error_message] << $!.backtrace.map{|x| "\t#{x}"}.join("\n")
    end

    trigger_when_finished_callbacks(callbacks)
  end

  def self.execute(*args, fail_with: nil)
    output, status = Open3.capture2e(*args)
    exception = fail_with || RuntimeError
    raise exception.new(output) unless status.success?
    output
  end

  # Runs Bundler in the current working directory.
  def self.bundle
    Bundler.with_clean_env do
      execute(
        'bundle', 'install', '--frozen', '--retry', '3', '--jobs', '3',
        fail_with: BundleError
      )
    end
  end
end

require 'perf_check/app'
require 'perf_check/callbacks'
require 'perf_check/config'
require 'perf_check/git'
require 'perf_check/output'
require 'perf_check/server'
require 'perf_check/test_case'

if defined?(Rails) && ENV['PERF_CHECK']
  require 'perf_check/railtie'
end
