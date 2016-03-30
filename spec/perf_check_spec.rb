
require 'spec_helper'

RSpec.describe PerfCheck do
  let(:perf_check) do
    PerfCheck.new('tmp/spec').tap{ |x| x.logger = Logger.new('/dev/null') }
  end

  describe "#load_config" do
    it "should require app_root/config/perf_check" do
      config_file = "#{perf_check.app_root}/config/perf_check"
      system("mkdir", "-p", File.dirname(config_file))
      system("touch", config_file)

      expect(perf_check).to receive(:require).with(config_file)
      perf_check.load_config
    end
  end

  describe "#add_test_case(route)" do
    it "should create add a new PerfCheck::TestCase to #test_cases" do
      expect(perf_check.test_cases.size).to eq(0)
      perf_check.add_test_case('/xyz')

      expect(perf_check.test_cases.size).to eq(1)
      expect(perf_check.test_cases[0].resource).to eq('/xyz')
    end

    context "when route does not begin with a slash" do
      it "should prepend a slash to route" do
        perf_check.add_test_case('xyz')
        expect(perf_check.test_cases[0].resource).to eq('/xyz')
      end
    end
  end

  describe "#run" do
    it "should run profile_requests, stash if needed, checkout the ref branch, and profile again"

    it "should ensure that server is shut down"

    it "should ensure that current branch is checked out"

    it "should ensure that anything stashed is popped"
  end

  describe "#profile_requests" do
    before do
      allow(perf_check.server).to receive(:restart)
    end

    it "should not run migrations_up if !options.run_migrations?" do
      expect(perf_check).not_to receive(:run_migrations_up)
      perf_check.send :profile_requests
    end

    it "should run migrations if options.run_migrations" do
      perf_check.options[:run_migrations?] = true

      expect(perf_check).to receive(:run_migrations_up)
      expect(perf_check).to receive(:run_migrations_down)
      perf_check.send :profile_requests
    end

    it "should ensure to run migrations down if options.run_migrations?" do
      perf_check.options[:run_migrations?] = true

      expect(perf_check).to receive(:run_migrations_up)
      expect(perf_check).to receive(:run_migrations_down)
      allow(perf_check.server).to receive(:restart){ raise Exception.new }
      expect{ perf_check.send :profile_requests }.to raise_error(Exception)
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
  end

  describe "#run_migrations_up" do
    it "should bundle exec rake db:migrate"
  end

  describe "#run_migrations_down" do
    it "should bundle exec rake db:migrate:down each migration on the test branch"

    it "should git.clean_db"
  end
end
