
require 'spec_helper'
require 'securerandom'

RSpec.describe PerfCheck::Git do
  repo = "tmp/spec_repo"
  repo_file = "file"
  feature_branch = "another_branch"
  before do
    system("
      rm -rf #{repo}         &&
      mkdir -p #{repo}       &&
      cd #{repo}             &&
      git init >/dev/null    &&
      touch #{repo_file}     &&
      git add #{repo_file}   &&
      git commit -m 'Initialize test repo' >/dev/null &&
      git branch #{feature_branch}
    ") or abort("Couldn't initialize test repo at #{repo}")
  end

  let(:perf_check){ double(app_root: repo, logger: Logger.new('/dev/null')) }

  describe "#initialize" do
    it "should find the current branch checked out in perf_check.app_root" do
      git = PerfCheck::Git.new(perf_check)
      expect(git.current_branch).to eq("master")
    end

    it "should initialize #logger to perf_check.logger" do
      git = PerfCheck::Git.new(perf_check)
      expect(git.logger).to eq(perf_check.logger)
    end
  end

  describe "#checkout(branch, bundle)" do
    it "should checkout the branch" do
      git = PerfCheck::Git.new(perf_check)
      git.checkout(feature_branch)

      branch = `cd #{repo} && git rev-parse --abbrev-ref HEAD`.strip
      expect(branch).to eq(feature_branch)
    end

    context "when branch doesn't exist" do
      it "should raise Git::NoSuchBranch" do
        git = PerfCheck::Git.new(perf_check)
        expect{ git.checkout("no_branch_such_as_this") }.
          to raise_error(PerfCheck::Git::NoSuchBranch)
      end
    end
  end

  describe "#checkout_reference(ref)" do
    it "should checkout master by default" do
      `cd #{repo} && git checkout #{feature_branch}`

      git = PerfCheck::Git.new(perf_check)
      git.checkout_reference

      branch = `cd #{repo} && git rev-parse --abbrev-ref HEAD`.strip
      expect(branch).to eq("master")
    end

    it "should setup a callback to check the current branch back out" do
      pending "this isn't set up yet"
    end
  end

  describe "#checkout_current_branch" do
    it "is an alias for checkout(current_branch)" do
      git = PerfCheck::Git.new(perf_check)
      expect(git).to receive(:checkout).with(git.current_branch, true)
      git.checkout_current_branch
    end
  end

  describe "#anything_to_stash?" do
    it "should be true when there are changes in the working tree" do
      system("cd #{repo} && echo #{SecureRandom.hex(8)} >#{repo_file}")

      git = PerfCheck::Git.new(perf_check)
      expect(git.anything_to_stash?).to eq(true)
    end

    it "should be true when there are staged changes" do
      system("cd #{repo} && echo #{SecureRandom.hex(8)} >#{repo_file}")
      system("cd #{repo} && git add #{repo_file}")

      git = PerfCheck::Git.new(perf_check)
      expect(git.anything_to_stash?).to eq(true)
    end

    it "should be false when there are no working/staged changes" do
      git = PerfCheck::Git.new(perf_check)
      expect(git.anything_to_stash?).to eq(false)
    end
  end

  describe "#stash_if_needed" do
    it "should call git stash if there are changes" do
      system("cd #{repo} && echo #{SecureRandom.hex(8)} >#{repo_file}")

      git = PerfCheck::Git.new(perf_check)
      expect(git).to receive(:anything_to_stash?){ true }
      git.stash_if_needed

      expect(File.read("#{repo}/#{repo_file}")).to eq("")
      expect(`git stash list`.lines.size).to eq(1)
    end
  end

  describe "#pop" do
    it "should execute git pop" do
      changes = SecureRandom.hex(8)
      system("cd #{repo} && echo #{changes} >#{repo_file} && git stash")

      expect(File.read("#{repo}/#{repo_file}")).to eq("")

      git = PerfCheck::Git.new(perf_check)
      git.pop
      expect(File.read("#{repo}/#{repo_file}").strip).to eq(changes)
    end
  end

  describe "#migrations_to_run_down" do
    it "should list those migrations on current_branch which are not on master" do
      pending "not spec'd"
    end
  end
end
