# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'bin/perf_check' do
  def perf_check(*args, stderr: false)
    bundle('exec', 'perf_check', *args)
  end

  RESULT_RE = /\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]\s+\d+:/

  context 'running on Rails 4' do
    around do |example|
      # NOTE: this changes the current working directory to the root of the app.
      using_app('rails-4') do
        link_perf_check
        run_bundle_install
        run_db_setup
        example.run
      end
    end

    describe '-q /posts' do
      it 'should issue 20 requests to /posts on current branch' do
        out = perf_check('-q', '/posts')
        log = out.lines.drop_while{ |x| x !~ /Benchmarking \/posts/ }
        expect(log.grep(RESULT_RE).size).to eq(20)
      end
    end

    describe '-qn 2 /posts' do
      it 'should issue 2 requests to /posts on current branch' do
        out = perf_check('-qn2', '/posts')
        log = out.lines.drop_while{ |x| x !~ /Benchmarking \/posts/ }
        expect(log.grep(RESULT_RE).size).to eq(2)
      end
    end

    describe '/posts' do
      it 'should issue 20 requests to /posts on current branch + master' do
        out = perf_check('/posts')

        log = out.lines.drop_while{ |x| x !~ /Benchmarking \/posts/ }
        log = log.take_while{ |x| x !~ /Checking out master/ }
        expect(log.grep(RESULT_RE).size).to eq(20)
        log = out.lines.drop_while{ |x| x !~ /Checking out master/ }
        expect(log.grep(RESULT_RE).size).to eq(20)

        log = out.lines.drop_while{ |x| x !~ /^=+ Results/ }
        expect(log.find{ |x| x =~ /reference: \d+\.\d+ms/ }).not_to be_nil
        expect(log.find{ |x| x =~ /your branch: \d+\.\d+ms/ }).not_to be_nil
        expect(log.find{ |x| x =~ /change: -?\d+\.\d+ms/ }).not_to be_nil
      end
    end
  end

  context 'running on Rails 5' do
    around do |example|
      # NOTE: this changes the current working directory to the root of the app.
      using_app('rails-5') do
        link_perf_check
        run_bundle_install
        run_db_setup
        example.run
      end
    end

    it 'performs 20 requests against current branch and master' do
      out = perf_check('/posts')
      expect(out.lines.grep(RESULT_RE).size).to eq(40)
    end
  end
end
