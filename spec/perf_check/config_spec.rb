require 'spec_helper'

RSpec.describe PerfCheck do
  let(:perf_check) { PerfCheck.new('test_app') }
  context "option parser" do
    it "allows the --shell option to turn on the spawn_shell option" do
      expect(perf_check.options.spawn_shell).to eq(false)
      perf_check.parse_arguments(%w(--shell))
      expect(perf_check.options.spawn_shell).to eq(true)
    end
  end
end
