require 'spec_helper'
require 'json'

RSpec.describe "bin/perf_check" do
  def perf_check(*args, stderr: false)
    Bundler.with_clean_env do
      tail = stderr ? " 2>&1" : "2>/dev/null"
      `cd test_app && bundle exec perf_check #{args.join(' ')} #{tail}`
    end
  end

  before do
    system("cd test_app && git checkout . && git checkout -q test_branch")
  end

  describe 'bundler' do
    it 'should not fail on the test app' do
      out = perf_check(stderr:true)
      expect(out).to include('Usage: perf_check')
    end
  end

  describe "-q /posts" do
    it "should issue 20 requests to /posts on current branch" do
      out = perf_check("-q", "/posts", stderr: true)
      log = out.lines.drop_while{ |x| x !~ /Benchmarking \/posts/ }
      expect(log.grep(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]\s+\d+:/).size).to eq(20)
    end
  end

  describe "-qn 2 /posts" do
    it "should issue 2 requests to /posts on current branch" do
      out = perf_check("-qn2", "/posts", stderr: true)
      log = out.lines.drop_while{ |x| x !~ /Benchmarking \/posts/ }
      expect(log.grep(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]\s+\d+:/).size).to eq(2)
    end
  end

  describe "/posts" do
    it "should issue 20 requests to /posts on current branch + master" do
      out = perf_check("/posts", stderr: true)
      log = out.lines.drop_while{ |x| x !~ /Benchmarking \/posts/ }
      log = log.take_while{ |x| x !~ /Checking out master/ }

      expect(log.grep(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]\s+\d+:/).size).to eq(20)

      log = out.lines.drop_while{ |x| x !~ /Checking out master/ }
      expect(log.grep(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]\s+\d+:/).size).to eq(20)

      log = out.lines.drop_while{ |x| x !~ /^=+ Results/ }
      expect(log.find{ |x| x =~ /reference: \d+\.\d+ms/ }).not_to be_nil
      expect(log.find{ |x| x =~ /your branch: \d+\.\d+ms/ }).not_to be_nil
      expect(log.find{ |x| x =~ /change: [+-]\d+\.\d+ms/ }).not_to be_nil
    end
  end
end
