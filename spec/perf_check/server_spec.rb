
require 'spec_helper'
require 'shellwords'

RSpec.describe PerfCheck::Server do
  let(:perf_check)  do
    perf_check_instance = PerfCheck.new('test_app')
    perf_check_instance.logger = Logger.new('/dev/null')
    perf_check_instance
  end
  let(:server) do
    system("mkdir", "-p", "tmp/spec/app")
    PerfCheck::Server.new(perf_check)
  end

  after(:all) do
    FileUtils.rm_rf('tmp/spec')
  end

  describe "#start" do

    after(:each) do
      server.exit
    end

    before do
      allow(Dir).to receive(:chdir).and_call_original
      allow(Process).to receive(:spawn) { 0 }
      allow(Process).to receive(:wait)
    end

    let(:perf_check_shell_command) {
      "bundle exec rails server -b #{server.host} -d -p #{server.port} -e development"
    }
    let(:perf_check_server_file_descriptors) { { [:out] => '/dev/null' } }

    it "should spawn a daemonized rails server from app_root on #host:#port" do
      app_root = Shellwords.shellescape(server.perf_check.app_root)
      expect(Dir).to receive(:chdir).with(app_root).and_call_original

      expect(Process).to receive(:spawn).with(
        { 'PERF_CHECK' => '1', 'DISABLE_SPRING' => '1' },
        perf_check_shell_command,
        a_hash_including(perf_check_server_file_descriptors)
      ).once

      allow(server).to receive(:sleep)
      server.start
    end

    it "should cause the server to run" do
      allow(server).to receive(:system)
      allow(server).to receive(:sleep)

      expect(server.running?).to be_falsey
      server.start
      expect(server.running?).to be true
    end

    context "when building Process.spawn argument hash from perf_check.options" do
      before do
        allow(server).to receive(:system)
        allow(server).to receive(:sleep)
      end

      context "when setting PERF_CHECK_VERIFICATION" do
        before do
          allow(perf_check).to receive_message_chain(:options, :caching) { false }
          allow(perf_check).to receive_message_chain(:options, :environment) { nil }
          allow(perf_check).to receive_message_chain(:options, :verify_no_diff) { verify_no_diff }
        end
        context "when options.verify_no_diff is true" do
          let(:verify_no_diff) { true }
          it "sets PERF_CHECK_VERIFICATION key in hash" do
            expect(Process).to receive(:spawn).with(
              a_hash_including(
                'PERF_CHECK' => '1',
                'PERF_CHECK_VERIFICATION' => '1',
                'PERF_CHECK_NOCACHING' => '1'
              ),
              perf_check_shell_command,
              a_hash_including(perf_check_server_file_descriptors)
            ).once

            server.start
          end
        end
        context "when options.verify_no_diff is false" do
          let(:verify_no_diff) { false }
          it "does not set PERF_CHECK_VERIFICATION key in hash" do
            expect(Process).to receive(:spawn).with(
              a_hash_including(
                'PERF_CHECK' => '1',
                'PERF_CHECK_NOCACHING' => '1'
              ),
              perf_check_shell_command,
              a_hash_including(perf_check_server_file_descriptors)
            ).once

            server.start
          end
        end
      end

      context "when setting PERF_CHECK_NO_CACHING" do
        before do
          allow(perf_check).to receive_message_chain(:options, :verify_no_diff) { false }
          allow(perf_check).to receive_message_chain(:options, :environment) { nil }
          allow(perf_check).to receive_message_chain(:options, :caching) { caching }
        end
        context "when options.caching is false" do
          let(:caching) { false }
          it "sets PERF_CHECK_NOCACHING key in hash" do
            expect(Process).to receive(:spawn).with(
              a_hash_including(
                'PERF_CHECK' => '1',
                'PERF_CHECK_NOCACHING' => '1'
              ),
              perf_check_shell_command,
              a_hash_including(perf_check_server_file_descriptors)
            ).once

            server.start
          end
        end

        context "when options.caching is true" do
          let(:caching) { true }
          it "does not set PERF_CHECK_NOCACHING key in hash" do
            expect(Process).to receive(:spawn).with(
              a_hash_including(
                'PERF_CHECK' => '1'
              ),
              perf_check_shell_command,
              a_hash_including(perf_check_server_file_descriptors)
            ).once

            server.start
          end
        end
      end
    end
  end

  describe "exit" do
    it "should kill -KILL pid" do
      expect(server).to receive(:pid){ 12345 }.at_least(:once)
      expect(Process).to receive(:kill).with('KILL', 12345)
      allow(server).to receive(:sleep)
      server.exit
    end
  end

  describe "#pid" do
    after(:each) do
      system("rm #{server.perf_check.app_root}/tmp/pids/server.pid")
    end

    it "should read app_root/tmp/pids/server.pid" do
      system("mkdir", "-p", "#{server.perf_check.app_root}/tmp/pids")
      system("echo 12345 >#{server.perf_check.app_root}/tmp/pids/server.pid")
      expect(server.pid).to eq(12345)
    end
  end

  describe "#restart" do
    context "already running" do
      it "should exit then start" do
        expect(server).to receive(:running?){ true }.ordered
        expect(server).to receive(:exit).ordered
        expect(server).to receive(:start).ordered
        server.restart
      end
    end

    context "not running yet" do
      it "should start" do
        expect(server).to receive(:running?){ false }.ordered
        expect(server).not_to receive(:exit)
        expect(server).to receive(:start).ordered
        server.restart
      end
    end
  end

  describe "#profile(&block)" do
    let(:net_http) do
      http = double()
      expect(http).to receive(:start).ordered
      expect(http).to receive(:finish).ordered
      expect(http).to receive(:read_timeout=)
      http
    end

    let(:http_response) do
      OpenStruct.new(
        'X-Runtime' => '120.5',
        'X-PerfCheck-Query-Count' => '80',
        :code => '200',
        :body => 'body'
      )
    end

    before do
      expect(Net::HTTP).to receive(:new){ net_http }
      expect(server).to receive(:prepare_to_profile)
      allow(server).to receive(:mem){ 12345 }
      allow(server).to receive(:latest_profiler_url){ "/abcxyz" }.at_least(:once)
    end

    it "should yield a Net::HTTP to block" do
      server.profile do |http|
        expect(http).to eq(net_http)
        http_response
      end
    end

    it "should create a Profile with results from the response" do
      prof = server.profile do |http|
        http_response
      end

      expect(prof.latency).to eq(1000*http_response['X-Runtime'].to_f)
      expect(prof.query_count).to eq(http_response['X-PerfCheck-Query-Count'].to_i)
      expect(prof.profile_url).to eq(server.latest_profiler_url)
      expect(prof.response_code).to eq(http_response.code.to_i)
      expect(prof.response_body).to eq(http_response.body)
      expect(prof.server_memory).to eq(server.mem)
      expect(prof.backtrace).to be_nil
    end

    it "should include backtrace in the profile if request raised an exception" do
      FileUtils.mkdir_p("tmp/spec")
      File.open("tmp/spec/request_backtrace.txt", "w"){ |f| f.write("one\ntwo") }
      http_response['X-PerfCheck-StackTrace'] = "tmp/spec/request_backtrace.txt"

      prof = server.profile do |http|
        http_response
      end

      expect(prof.backtrace).to eq(["one", "two"])
    end

    it "should raise a PerfCheck::Exception if it cant connect" do
      expect do
        server.profile do |http|
          http.finish
          raise Errno::ECONNREFUSED.new
        end
      end.to raise_error(PerfCheck::Exception)
    end
  end

  describe "#mem" do
    it "should give the rss size of #pid in kilobytes"
  end

  describe "prepare_to_profile" do
    it "should clean app_root/tmp/perf_check/miniprofiler"
  end

  describe "latest_profiler_url" do
    it "should a url to the miniprofiler result from the last profile"
  end
end
