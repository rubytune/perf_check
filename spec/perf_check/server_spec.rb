
require 'spec_helper'
require 'shellwords'

RSpec.describe PerfCheck::Server do
  let(:server) do
    system("mkdir", "-p", "tmp/spec/app")
    perf_check = PerfCheck.new('test_app')
    perf_check.logger = Logger.new('/dev/null')
    PerfCheck::Server.new(perf_check)
  end

  TEST_PID = 123456789
  TEST_MEM = 54321

  after(:all) do
    FileUtils.rm_rf('tmp/spec')
  end

  describe "#start" do

    after(:each) do
      server.exit
    end

    it "should spawn a daemonized rails server from app_root on #host:#port" do
      expect(server).to receive(:`) do |command|
        app_root = Shellwords.shellescape(server.perf_check.app_root)
        expect(command).to match("-b #{server.host}")
        expect(command).to match("-p #{server.port}")
        expect(command).to match("-d")
      end

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

    it "should set env variables based on envars argument" do
      ENV['PERF_CHECK']              = 'nope'
      ENV['PERF_CHECK_VERIFICATION'] = 'nope'
      ENV['PERF_CHECK_NOCACHING']    = 'nope'
      ENV['TEST_VAR']                = 'nope'

      envars = {
          'PERF_CHECK'              => '1',
          'PERF_CHECK_VERIFICATION' => '1',
          'PERF_CHECK_NOCACHING'    => '0',
          'TEST_VAR'                => 'okay'
      }
      allow(server).to receive(:system)
      allow(server).to receive(:sleep)
      expect(server).to receive(:start).with(any_args).and_call_original

      server.start(envars)
      expect(ENV['PERF_CHECK']).to              eq '1'
      expect(ENV['PERF_CHECK_VERIFICATION']).to eq '1'
      expect(ENV['PERF_CHECK_NOCACHING']).to    eq '0'
      expect(ENV['TEST_VAR']).to                eq 'okay'
    end
  end

  describe "#exit" do

    before do
      FileUtils.mkdir_p(File.dirname(server.pid_file)) unless File.exist?(server.pid_file)
      File.open(server.pid_file, 'w+') { |file| file.puts TEST_PID }
    end

    it "should kill -QUIT pid" do
      server.start
      allow(server).to receive(:sleep)
      expect(server).to receive(:pid).at_least(:once).and_call_original
      expect(server).to receive(:is_live_pid?).at_least(:once).and_return(true)
      expect(server).to receive(:kill_process).with(TEST_PID).and_call_original
      expect(server).to receive(:kill_pid).at_least(:once).with('QUIT', TEST_PID)
      expect(server).to receive(:kill_pid).at_least(:once).with('KILL', TEST_PID)
      expect(server).to receive(:wait_pid).with(TEST_PID).and_return(false, true)
      expect(server).to receive(:remove_pid_file).and_call_original
      server.exit
    end
  end

  describe "#pid_file" do
    let(:pid_dir) { File.join(server.perf_check.app_root, "/tmp/pids") }
    it "should return a path to the file holding the server pid" do
      expect(server.pid_file).to eq File.join(pid_dir, 'server.pid')
    end
  end

  describe "#pid" do
    after { server.remove_pid_file }
    it "should read the number at pid_file" do
      pid_dir = File.dirname(server.pid_file)
      File.mkdir_p(File.dirname(pid_dir)) unless Dir.exist?(pid_dir)
      File.open(server.pid_file, 'w+') {|file| file.puts TEST_PID }
      expect(server.pid).to eq(TEST_PID)
    end
  end

  describe "#restart" do
    context "already running" do
      it "should exit then start" do
        expect(server).to receive(:running?).at_least(:once){ true }.ordered
        expect(server).to receive(:exit).ordered
        expect(server).to receive(:start).ordered
        server.restart
      end
    end

    context "not running yet" do
      it "should start" do
        expect(server).to receive(:running?).at_least(:once){ false }.ordered
        expect(server).not_to receive(:exit)
        expect(server).to receive(:start).ordered
        server.restart
      end
    end
  end

  describe "#profile(&block)" do
    let(:net_http) do
      http = double()
      allow(http).to  receive(:start).with(no_args)
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
      allow(server).to receive(:mem){ TEST_MEM }
      allow(server).to receive(:latest_profiler_url){ "/abcxyz" }.at_least(:once)
      allow(server).to receive(:start)
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
