
require 'spec_helper'

RSpec.describe PerfCheck do
  let(:perf_check) do
    FileUtils.mkdir_p("tmp/spec")
    PerfCheck.new('tmp/spec').tap{ |x| x.logger = Logger.new('/dev/null') }
  end

  after(:all) do
    FileUtils.rm_rf('tmp/spec')
  end

  describe "#load_config" do
    it "should require app_root/config/perf_check" do
      config_file = "#{perf_check.app_root}/config/perf_check.rb"
      system("mkdir", "-p", File.dirname(config_file))
      File.open(config_file, "w").close

      expect(perf_check).to receive(:load).with(config_file)
      perf_check.load_config
    end

    it "should rescue exceptions from the config file" do
      config_file = "#{perf_check.app_root}/config/perf_check.rb"
      system("mkdir", "-p", File.dirname(config_file))
      File.open(config_file, "w"){ |f| f.write("nil.do_something_you_cant") }

      expect{ perf_check.load_config }.to raise_error(PerfCheck::ConfigLoadError)
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
