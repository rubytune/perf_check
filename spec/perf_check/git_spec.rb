require 'spec_helper'
require 'securerandom'

RSpec.describe PerfCheck::Git do
  repo = File.join(__dir__, "tmp/spec/repo")
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

  after(:all) do
    FileUtils.rm_rf('tmp/spec')
  end

  let(:perf_check){ double(app_root: repo, logger: Logger.new('/dev/null')) }
  let(:git){ PerfCheck::Git.new(perf_check) }

  describe "#initialize" do
    it "should find the current branch checked out in perf_check.app_root" do
      expect(git.current_branch).to eq("master")
    end

    it "should initialize #logger to perf_check.logger" do
      expect(git.logger).to eq(perf_check.logger)
    end
  end

  describe "#checkout(branch, bundle)" do
    it "should checkout the branch" do
      git.checkout(feature_branch)

      branch = `cd #{repo} && git rev-parse --abbrev-ref HEAD`.strip
      expect(branch).to eq(feature_branch)
    end

    it "should raise BundleError if `bundle` fails"

    context "when branch doesn't exist" do
      it "should raise Git::NoSuchBranch" do
        expect{ git.checkout("no_branch_such_as_this") }.
          to raise_error(PerfCheck::Git::NoSuchBranch)
      end
    end
  end

  describe "#checkout_reference(ref)" do
    it "should checkout master by default" do
      `cd #{repo} && git checkout #{feature_branch}`

      git.checkout_reference

      branch = `cd #{repo} && git rev-parse --abbrev-ref HEAD`.strip
      expect(branch).to eq("master")
    end
  end

  describe "#checkout_current_branch" do
    it "is an alias for checkout(current_branch)" do
      expect(git).to receive(:checkout).with(git.current_branch, true)
      git.checkout_current_branch
    end
  end

  describe "#anything_to_stash?" do
    it "should be true when there are changes in the working tree" do
      system("cd #{repo} && echo #{SecureRandom.hex(8)} >#{repo_file}")
      expect(git.anything_to_stash?).to eq(true)
    end

    it "should be true when there are staged changes" do
      system("cd #{repo} && echo #{SecureRandom.hex(8)} >#{repo_file}")
      system("cd #{repo} && git add #{repo_file}")
      expect(git.anything_to_stash?).to eq(true)
    end

    it "should be false when there are no working/staged changes" do
      expect(git.anything_to_stash?).to eq(false)
    end
  end

  describe "#stash_if_needed" do
    it "should call git stash if there are changes" do
      system("cd #{repo} && echo #{SecureRandom.hex(8)} >#{repo_file}")

      git.stash_if_needed

      expect(File.read("#{repo}/#{repo_file}")).to eq("")
      expect(git.anything_to_stash?).to eq(false)
    end

    it "should raise StashError if `git stash` fails"
  end

  describe "#pop" do
    it "should execute git stash pop" do
      changes = SecureRandom.hex(8)
      system("cd #{repo} && echo #{changes} >#{repo_file} && git stash")

      expect(File.read("#{repo}/#{repo_file}")).to eq("")

      git.pop
      expect(File.read("#{repo}/#{repo_file}").strip).to eq(changes)
    end

    it "should raise StashPopError if `git stash pop` fails"
  end

  describe "#migrations_to_run_down" do
    before do
      system("cd #{repo} && git checkout -b a_branch")
      system("mkdir", "-p", "#{repo}/db/migrate")
    end
    after { system("cd #{repo} && git checkout master") }

    it "should be empty by default" do
      expect(git.migrations_to_run_down).to be_empty
    end

    it "should list those versions on current_branch which are not on master" do
      File.open("#{repo}/db/migrate/12345_xyz.rb", "w"){ }
      system("cd #{repo} && git add db/migrate/12345_xyz.rb && git commit -m 'migration'")
      expect(git.migrations_to_run_down).to eq(["12345"])
    end
  end
end
