
require 'spec_helper'

RSpec.describe PerfCheck::Server do
  let(:server) do
    perf_check = PerfCheck.new('tmp/spec/app')
    perf_check.logger = Logger.new('/dev/null')
    PerfCheck::Server.new(perf_check)
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
end
