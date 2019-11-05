# frozen_string_literal: true

module Support
  # Helpers to prepare app directories for integration testing.
  module Apps
    # Returns the directory that holds all the app bundles.
    def self.bundle_dir
      File.expand_path('../bundles', __dir__)
    end

    # Returns a path to a tarball for the specified bundle name.
    def self.app_bundle_path(name)
      File.join(bundle_dir, "#{name}.tar.bz2")
    end

    def self.minimal_app_dir
      minimal_app.app_dir
    end

    def self.minimal_app
      @minimal_app ||= begin
        app = PerfCheck::App.new(
          bundle_path: app_bundle_path('minimal'),
          app_dir: Dir.mktmpdir('perf-check-minimal')
        )
        app.unpack
        app
      end
    end

    def minimal_app_dir
      Support::Apps.minimal_app_dir
    end

    def app_bundle_path(name)
      Support::Apps.app_bundle_path(name)
    end

    # Unpacks an app, changes directory to that app, and calls the block.
    def using_app(name, &block)
      using_tmpdir do |app_dir|
        PerfCheck::App.new(
          bundle_path: Support::Apps.app_bundle_path(name),
          app_dir: app_dir
        ).unpack
        Dir.chdir(app_dir, &block)
      end
    end

    # Because apps are unpacked to a temporary directory we need to symlink
    # the perf_check project root from the application directory in order to
    # use it easily from the Gemfile.
    def link_perf_check
      execute('ln', '-s', perf_check_project_root, 'perf_check')
    end

    def run_bundle_install
      # Use the --frozen option to prevent the test suite from writing a new
      # Gemfile.lock.
      bundle 'install', '--frozen', '--retry', '3', '--jobs', '3'
    end

    def run_db_setup
      bundle 'exec', 'rake', 'db:setup'
    end

    # Prints a lot of stuff to STDOUT so we can see if the isolated app was
    # unpacked an functioning properly.
    def inspect_app
      puts "SOURCE"
      puts
      puts execute('ls', '-al')
      puts
      puts "BRANCHES"
      puts
      puts git('branch', '-a')
      puts
      puts "PIDS"
      puts
      puts execute('ls', '-al', 'tmp/pids')
      puts
      puts "PROCESSES"
      puts
      puts execute('ps', 'ax').lines.grep(%r{rails}).join("\n")
      puts
      puts "LOGS"
      Dir.glob('log/*.log').each do |filename|
        puts
        puts ">> #{filename}"
        puts
        puts File.read(filename)
      end
    end
  end
end
