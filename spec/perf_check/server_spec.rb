
require 'spec_helper'
require 'shellwords'

RSpec.describe PerfCheck::Server do
  let(:server) do
    perf_check = PerfCheck.new('tmp/spec/app')
    perf_check.logger = Logger.new('/dev/null')
    PerfCheck::Server.new(perf_check)
  end

  describe "#start" do
    it "should spawn a daemonized rails server from app_root on #host:#port" do
      expect(server).to receive(:system) do |command|
        app_root = Shellwords.shellescape(server.perf_check.app_root)
        expect(command).to match("cd #{app_root}")
        expect(command).to match("-b #{server.host}")
        expect(command).to match("-p #{server.port}")
        expect(command).to match("-d")
      end

      allow(server).to receive(:sleep)

      server.start
    end

    it "should cause the server to go running?" do
      allow(server).to receive(:system)
      allow(server).to receive(:sleep)

      expect(server.running?).to be_falsey
      server.start
      expect(server.running?).to be true
    end

    it "should set env variables depending on perf_check options" do
      ENV['PERF_CHECK'] = '0'
      ENV['PERF_CHECK_VERIFICATION'] = '0'
      ENV['PERF_CHECK_NOCACHING'] = '0'
      allow(server).to receive(:system)
      allow(server).to receive(:sleep)

      server.start
      expect(ENV['PERF_CHECK']).to eq('1')
      expect(ENV['PERF_CHECK_VERIFICATION']).to eq('0')
      expect(ENV['PERF_CHECK_NOCACHING']).to eq('0')

      server.perf_check.options.verify_responses = true
      server.start
      expect(ENV['PERF_CHECK_VERIFICATION']).to eq('1')
      expect(ENV['PERF_CHECK_NOCACHING']).to eq('0')

      server.perf_check.options.caching = false
      server.start
      expect(ENV['PERF_CHECK_NOCACHING']).to eq('1')
    end
  end

  describe "#exit" do
    it "should kill -QUIT pid" do
      expect(server).to receive(:pid){ 12345 }.at_least(:once)
      expect(Process).to receive(:kill).with('QUIT', 12345)
      allow(server).to receive(:sleep)
      server.exit
    end
  end

  describe "#pid" do
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
