require 'spec_helper'

RSpec.describe PerfCheck do
  let(:perf_check) { PerfCheck.new('test_app') }

  context "option parser" do
    it "allows the --deployment options to turn on automated mode" do
      perf_check.parse_arguments(%w(--deployment))
      expect(perf_check.options.automated).to eq(true)
    end

    it "allows the --shell option to turn on the spawn_shell option" do
      expect(perf_check.options.spawn_shell).to eq(false)
      perf_check.parse_arguments(%w(--shell))
      expect(perf_check.options.spawn_shell).to eq(true)
    end

    it "allows the --verbose option to turn on verbose logging" do
      expect(perf_check.options.verbose).to eq(false)
      perf_check.parse_arguments(%w(--verbose))
      expect(perf_check.options.verbose).to eq(true)
    end
  end
end
