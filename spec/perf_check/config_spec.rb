require 'spec_helper'

RSpec.describe PerfCheck do
  let(:perf_check) { PerfCheck.new('test_app') }

  context "defaults" do
    it "only tests against master" do
      expect(perf_check.options.branch).to eq('master')
      expect(perf_check.options.reference).to be_nil
    end
  end

  context "option parser" do
    it "allows the --shell option to turn on the spawn_shell option" do
      expect(perf_check.options.spawn_shell).to eq(false)
      perf_check.parse_arguments(%w(--shell))
      expect(perf_check.options.spawn_shell).to eq(true)
    end

    it "allows the --reference option to change the reference branch" do
      expect(perf_check.options.reference).to be_nil
      perf_check.parse_arguments(%w(--reference slower))
      expect(perf_check.options.reference).to eq('slower')
    end
  end
end
