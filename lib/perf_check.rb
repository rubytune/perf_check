require 'net/http'
require 'digest'
require 'fileutils'
require 'benchmark'
require 'ostruct'
require 'colorize'
require 'logger'

class PerfCheck
  class Exception < ::Exception; end
  class ConfigLoadError < Exception; end

  attr_reader :app_root, :options, :git, :server, :test_cases
  attr_accessor :logger

  def initialize(app_root)
    @app_root = app_root
    @options = OpenStruct.new(
      number_of_requests: 20,
      reference: 'master',
      branch: nil,
      cookie: nil,
      headers: {},
      http_statuses: [200],
      verify_no_diff: false,
      diff: false,
      diff_options: ['-U3',
                     '--ignore-matching-lines=/mini-profiler-resources/includes.js'],
      brief: false,
      caching: true,
      json: false,
      hard_reset: false,
      environment: 'development',
    )

    @logger = Logger.new(STDERR).tap do |logger|
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime("%Y-%m-%d %H:%M:%S")}] #{msg}\n"
      end
    end

    @git = Git.new(self)
    @server = Server.new(self)
    @test_cases = []
  end

  def load_config
    File.stat(File.join(app_root,'Gemfile')).file?
    if File.exists?("#{app_root}/config/perf_check.rb")
      this = self
      Kernel.send(:define_method, :perf_check){ this }

      dir = Dir.pwd
      begin
        Dir.chdir(app_root)
        load "#{app_root}/config/perf_check.rb"
      rescue LoadError => e
        error = ConfigLoadError.new(e.message)
        error.set_backtrace(e.backtrace)
        raise error
      ensure
        Dir.chdir(dir)
        Kernel.send(:remove_method, :perf_check)
      end
    end
  end

  def add_test_case(route)
    test_cases.push(TestCase.new(self, route.sub(/^([^\/])/, '/\1')))
  end

  def run
    begin
      if options.compare_paths?
        raise "Must have two paths" if test_cases.count != 2
        profile_compare_paths_requests
      else
        profile_requests
        if options.reference
          git.stash_if_needed
          git.checkout(options.reference, bundle_after_checkout: true, hard_reset: options.hard_reset)
          test_cases.each{ |x| x.switch_to_reference_context }

          profile_requests
        end
      end
    ensure
      server.exit
      if options.reference
        git.checkout(git.current_branch, bundle_after_checkout: true, hard_reset: options.hard_reset)
        git.pop if git.stashed?
      end

      callbacks = {}

      if $!
        callbacks[:error_message] = "#{$!.class}: #{$!.message}\n"
        callbacks[:error_message] << $!.backtrace.map{|x| "\t#{x}"}.join("\n")
      end

      trigger_when_finished_callbacks(callbacks)
    end
  end

  private

  def profile_compare_paths_requests
    first = test_cases[0]
    reference_test = test_cases[1]
    profile_test_case(first)
    reference_test.switch_to_reference_context
    profile_test_case(reference_test)
  end

  def profile_test_case(test)
    trigger_before_start_callbacks(test)
    run_migrations_up if options.run_migrations?
    server.restart

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
