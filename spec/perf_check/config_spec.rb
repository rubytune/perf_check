require 'spec_helper'

RSpec.describe PerfCheck do
  let(:perf_check) { PerfCheck.new('test_app') }

  context "option parser" do
    it "allows the -b option to select the experiment branch" do
      perf_check.parse_arguments(%w(-b lrz/optimizations))
      expect(perf_check.options.branch).to eq('lrz/optimizations')
    end

    it "allows the --branch option to select the experiment branch" do
      perf_check.parse_arguments(%w(--branch lrz/optimizations))
      expect(perf_check.options.branch).to eq('lrz/optimizations')
    end

    it "allows the --brief option to set brief output" do
      perf_check.parse_arguments(%w(--brief))
      expect(perf_check.options.brief).to eq(true)
    end

    it "allows the --deployment options to turn on deployment mode" do
      perf_check.parse_arguments(%w(--deployment))
      expect(perf_check.options.deployment).to eq(true)
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
