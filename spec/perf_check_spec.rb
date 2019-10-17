# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PerfCheck do
  around do |example|
    using_app('rails-4') do
      link_perf_check
      run_bundle_install
      example.run
    end
  end

  let(:output) { StringIO.new }
  let(:perf_check) do
    perf_check = PerfCheck.new(Dir.pwd)
    perf_check.logger = Logger.new(output)
    perf_check.options.spawn_shell = true
    perf_check
  end

  describe 'option parser' do
    it 'parses the environment' do
      perf_check.parse_arguments(%w[--environment staging])
      expect(perf_check.options.environment).to eq('staging')
    end

    it 'parses the number of requests' do
      perf_check.parse_arguments(%w[-n 43])
      expect(perf_check.options.number_of_requests).to eq(43)
    end

    it 'parses a relatively complex expression' do
      perf_check.parse_arguments(
        %w[
          --deployment
          --shell
          -n 2
          --branch UE-3965/faster    /4/co/cu/15
        ]
      )
      expect(perf_check.options.hard_reset).to eq(true)
      expect(perf_check.options.spawn_shell).to eq(true)
      expect(perf_check.options.number_of_requests).to eq(2)
      expect(perf_check.options.branch).to eq('UE-3965/faster')
    end

    it 'parses the verbose option' do
      perf_check.parse_arguments(%w[--verbose])
      expect(perf_check.options.verbose).to eq(true)
    end
  end

  describe "#run" do
    context 'when run_migrations is false' do
      before { perf_check.options[:run_migrations?] = false }

      it "should not run migrations" do
        perf_check.add_test_case('/xyz')

        allow(perf_check.test_cases.first).to receive(:run)
        expect(perf_check).not_to receive(:run_migrations_up)
        expect(perf_check).not_to receive(:run_migrations_down)
        perf_check.send :run
      end
    end

    context 'when run_migrations is true' do
      before { perf_check.options[:run_migrations?] = true }

      context 'with a reference branch' do
        before { perf_check.options[:reference] = :master }

        context 'when things go smoothly' do
          before do
            perf_check.add_test_case('/xyz')
            allow(perf_check.test_cases.first).to receive(:run)
          end

          it "should run migrations twice" do
            expect(perf_check).to receive(:run_migrations_up).twice
            expect(perf_check).to receive(:run_migrations_down).twice
            perf_check.send :run
          end
        end

        context 'when things go south' do
          before { allow(perf_check.server).to receive(:restart){ raise Exception.new } }

          it "should ensure to run migrations down" do
            perf_check.add_test_case('/xyz')

            expect(perf_check).to receive(:run_migrations_down)
            expect{ perf_check.send :run }.to raise_error(Exception)
          end
        end
      end

      context 'without a reference branch' do
        before { perf_check.options[:reference] = nil }

        context 'when things go smoothly' do
          before do
            perf_check.add_test_case('/xyz')
            allow(perf_check.test_cases.first).to receive(:run)
          end

          it "should run migrations once" do
            expect(perf_check).to receive(:run_migrations_up).once
            expect(perf_check).to receive(:run_migrations_down).once
            perf_check.send :run
          end
        end

        context 'when things go south' do
          before { allow(perf_check.server).to receive(:restart){ raise Exception.new } }

          it "should ensure to run migrations down" do
            perf_check.add_test_case('/xyz')

            expect(perf_check).to receive(:run_migrations_down)
            expect{ perf_check.send :run }.to raise_error(Exception)
          end
        end
      end
    end

    context "option compare_paths is on" do
      it do
        perf_check.options[:compare_paths?] = true
        perf_check.add_test_case('/xyz')
        perf_check.add_test_case('/xyz')
        expect(perf_check).to receive(:profile_compare_paths_requests)
        perf_check.send :run
      end
    end
  end

  describe "#profile_requests" do
    before do
      allow(perf_check.server).to receive(:restart)
    end

    it "should trigger before start callbacks and run each test case" do
      routes = ['/a', '/b', '/c']
      routes.each{ |r| perf_check.add_test_case(r) }

      perf_check.before_start do
      end

      callback = perf_check.before_start_callbacks[0]
      expect(callback).to receive(:call).exactly(routes.size).times

      perf_check.test_cases.each{ |test_case| expect(test_case).to receive(:run) }

      perf_check.send :profile_requests
    end

    it "should trigger when_finished callbacks after the run is over" do
      perf_check.add_test_case("/a")

      perf_check.when_finished do
      end

      callback = perf_check.when_finished_callbacks[0]
      expect(callback).to receive(:call).exactly(:once)

      perf_check.options.reference = nil
      allow(perf_check).to receive(:profile_requests)
      allow(perf_check.server).to receive(:exit)

      perf_check.run

      perf_check.when_finished_callbacks.clear

      error_message = nil
      perf_check.when_finished do |_, payload|
        error_message = payload[:error_message]
      end

      allow(perf_check).to receive(:profile_requests){ raise Exception.new }
      expect{ perf_check.run }.to raise_error(Exception)
      expect(error_message).not_to be_nil
    end
  end

  describe "#run_migrations_up" do
    it "should bundle exec rake db:migrate" do
      expect(perf_check).to receive(:"`") do |cmd|
        expect(cmd.scan("bundle exec rake db:migrate")).not_to be_empty
      end

      perf_check.send :run_migrations_up
    end

    it "should git.clean_db" do
      expect(perf_check).to receive(:"`")
      expect(perf_check.git).to receive(:clean_db)

      perf_check.send :run_migrations_up
    end
  end

  describe "#run_migrations_down" do
    it "should not do much if there are no migrations" do
      expect(perf_check.git).to receive(:migrations_to_run_down){ [] }
      expect(perf_check).not_to receive(:"`")

      perf_check.send :run_migrations_down
    end

    it "should bundle exec rake db:migrate:down each migration on the test branch" do
      expect(perf_check.git).to receive(:migrations_to_run_down){ ["123"] }
      expect(perf_check).to receive(:"`") do |cmd|
        expect(cmd.scan("bundle exec rake db:migrate:down VERSION=123")).not_to be_empty
      end

      perf_check.send :run_migrations_down
    end

    it "should git.clean_db" do
      expect(perf_check.git).to receive(:migrations_to_run_down){ [] }
      expect(perf_check.git).to receive(:clean_db)

      perf_check.send :run_migrations_down
    end
  end
end

RSpec.describe PerfCheck do
  it 'expands the app dir' do
    perf_check = PerfCheck.new('app')
    expect(perf_check.app_root).to eq(
      File.expand_path('../app', __dir__)
    )
  end

  it 'returns the path to its config script in the target application' do
    perf_check = PerfCheck.new('app')
    expect(perf_check.config_path).to eq(
      File.expand_path('../app/config/perf_check.rb', __dir__)
    )
  end

  it 'adds a test case with a request path' do
    perf_check = PerfCheck.new('app')
    expect(perf_check.test_cases.size).to be_zero

    request_path = '/books/42/authors?q=he'
    perf_check.add_test_case(request_path)
    expect(perf_check.test_cases.size).to eq(1)
    expect(perf_check.test_cases.last.resource).to eq(request_path)

    request_path = 'books/42/authors?q=ah'
    perf_check.add_test_case(request_path)
    expect(perf_check.test_cases.size).to eq(2)
    expect(perf_check.test_cases.last.resource).to eq('/' + request_path)
  end

  it 'uses the info log level by default' do
    perf_check = PerfCheck.new('app')
    expect(perf_check.logger.level).to eq(Logger::INFO)
  end

  it 'sets the log level to debug when running in verbose mode' do
    perf_check = PerfCheck.new('app')
    perf_check.options.verbose = true
    expect(perf_check.logger.level).to eq(Logger::DEBUG)
  end

  context 'operating on a Rails app' do
    around do |example|
      using_app('minimal') do
        example.run
      end
    end

    let(:output) { StringIO.new }
    let(:perf_check) do
      perf_check = PerfCheck.new(Dir.pwd)
      perf_check.logger = Logger.new(output)
      perf_check.options.spawn_shell = true
      perf_check
    end

    it 'benchmarks the specified branch and compares to master' do
      perf_check.parse_arguments(%w[--branch slower /])
      perf_check.run
      expect(output.string).to include('☕️')
      expect(output.string).to include('Benchmarking /')
      expect(output.string).to include('Checking out master and bundling')
    end

    it 'does not break when there is no config/perf_check.rb' do
      expect(perf_check.load_config).to be false
    end
  end

  context 'operating on a Rails app with config/perf_check.rb' do
    around do |example|
      using_app('minimal') do
        execute 'git', 'checkout', 'perf-check'
        example.run
      end
    end

    it 'executes code in perf_check.rb' do
      perf_check = PerfCheck.new(Dir.pwd)
      expect(perf_check.load_config).to be true
    end

    it 'successfully installed switches in the option parser' do
      perf_check = PerfCheck.new(Dir.pwd)
      perf_check.load_config
      perf_check.parse_arguments('--super')
      expect(perf_check.options.login_type).to eq(:super)
    end
  end

  context 'operating on a Rails app with broken config/perf_check.rb' do
    around do |example|
      using_app('minimal') do
        execute 'git', 'checkout', 'perf-check-broken'
        example.run
      end
    end

    it 'does not capture exceptions from perf_check.rb' do
      perf_check = PerfCheck.new(Dir.pwd)
      expect do
        perf_check.load_config
      end.to raise_error("Broken config/perf_check.rb")
    end
  end
end
