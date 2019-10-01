# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PerfCheck::Git do
  it 'allows logger to change on perf_check' do
    perf_check = PerfCheck.new(Dir.pwd)
    git = PerfCheck::Git.new(perf_check)
    expect(git.logger).to eq(perf_check.logger)
    perf_check.logger = Logger.new(nil)
    expect(git.logger).to eq(perf_check.logger)
  end

  context 'operating on a Rails app' do
    around do |example|
      using_app('minimal') do
        example.run
      end
    end

    let(:output) { StringIO.new }
    let(:perf_check) do
      perf_check = PerfCheck.new(Dir.pwd)
      perf_check.logger = Logger.new(output)
      perf_check
    end
    let(:feature_branch) { 'perf-check' }
    let(:non_existent_branch){ 'non-existent' }

    describe 'when initializing' do
      it 'finds the current branch checked out in perf_check.app_root' do
        git = PerfCheck::Git.new(perf_check)
        expect(git.current_branch).to eq('master')
      end

      it 'finds the branch specified in --branch if the option is set' do
        perf_check.options.branch = 'specified-branch'
        git = PerfCheck::Git.new(perf_check)
        expect(git.current_branch).to eq('specified-branch')
      end

      it 'initializes #logger to perf_check.logger' do
        git = PerfCheck::Git.new(perf_check)
        expect(git.logger).to eq(perf_check.logger)
      end
    end

    describe 'when checking out' do
      let(:git) { PerfCheck::Git.new(perf_check) }

      it 'checks out an existing branch' do
        git.checkout(feature_branch)
        branch = `git rev-parse --abbrev-ref HEAD`.strip
        expect(branch).to eq(feature_branch)
      end

      it 'checks out with a hard reset' do
        expect(File.exist?('config/perf_check.rb')).to be(false)
        git.checkout(feature_branch, hard_reset: true)
        branch = `git rev-parse --abbrev-ref HEAD`.strip
        expect(branch).to eq('master')
        expect(File.exist?('config/perf_check.rb')).to be(true)
      end

      it 'does not check out a non-existent branch' do
        expect do
          git.checkout(non_existent_branch)
        end.to raise_error(PerfCheck::Git::NoSuchBranch)
      end

      it 'fails when running Bundler fails' do
        expect do
          git.checkout('bundle-broken')
        end.to raise_error(PerfCheck::BundleError)
      end
    end

    describe 'detecting and stashing changes' do
      let(:git) { PerfCheck::Git.new(perf_check) }

      it 'knows there is nothing to stash when there are no changes' do
        expect(git.anything_to_stash?).to eq(false)
      end

      it 'is not stashed' do
        expect(git.stashed?).to eq(false)
      end

      it 'does not stash anything when there are no changes' do
        expect(git.stash_if_needed).to eq(false)
      end

      it 'fails when popping nothing' do
        expect do
          git.pop
        end.to raise_error(PerfCheck::Git::StashPopError)
      end

      context 'with changes to the working directory' do
        before do
          File.open('Gemfile', 'a') { |f| f.write("\n") }
        end

        it 'knows when there are changes to stash' do
          expect(git.anything_to_stash?).to eq(true)
        end

        it 'is not stashed' do
          expect(git.stashed?).to eq(false)
        end

        it 'stashes changes' do
          expect(git.stash_if_needed).to eq(true)
          expect(git.anything_to_stash?).to eq(false)
          expect(git.stashed?).to eq(true)
        end

        it 'knows when there are changes to stash when changes are staged' do
          `git add .`
          expect(git.anything_to_stash?).to eq(true)
        end

        it 'stashes staged changes' do
          `git add .`
          expect(git.stash_if_needed).to eq(true)
          expect(git.anything_to_stash?).to eq(false)
          expect(git.stashed?).to eq(true)
        end

        it 'pops stashed changes' do
          git.stash_if_needed
          expect(git.anything_to_stash?).to eq(false)
          git.pop
          expect(git.anything_to_stash?).to eq(true)
          expect(git.stashed?).to eq(false)
        end
      end
    end

    describe 'migrations' do
      let(:git) { PerfCheck::Git.new(perf_check) }

      it 'finds new migrations to run down' do
        git.checkout('migrations')
        expect(git.migrations_to_run_down).to_not be_empty
      end

      it 'does not find migrations to run down on master' do
        expect(git.migrations_to_run_down).to be_empty
      end

      it 'does not find migrations on feature branch without migrations' do
        git.checkout(feature_branch)
        expect(git.migrations_to_run_down).to be_empty
      end
    end
  end
end
