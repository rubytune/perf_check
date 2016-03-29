
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

  describe "-q /posts" do
    it "should issue 20 requests to /posts on current branch" do
      out = perf_check("-q", "/posts", stderr: true)
      log = out.lines.drop_while{ |x| x !~ /Benchmarking \/posts/ }
      expect(log.grep(/INFO --:\s+\d+:/).size).to eq(20)
    end
  end

  describe "-qn 7 /posts" do
    it "should issue 7 requests to /posts on current branch" do
      out = perf_check("-qn7", "/posts", stderr: true)
      log = out.lines.drop_while{ |x| x !~ /Benchmarking \/posts/ }
      expect(log.grep(/INFO --:\s+\d+:/).size).to eq(7)
    end
  end

  describe "/posts" do
    it "should issue 20 requests to /posts on current branch + master" do
      out = perf_check("/posts", stderr: true)
      log = out.lines.drop_while{ |x| x !~ /Benchmarking \/posts/ }
      log = log.take_while{ |x| x !~ /Checking out master/ }

      expect(log.grep(/INFO --:\s+\d+:/).size).to eq(20)

      log = out.lines.drop_while{ |x| x !~ /Checking out master/ }
      expect(log.grep(/INFO --:\s+\d+:/).size).to eq(20)

      log = out.lines.drop_while{ |x| x !~ /^=+ Results/ }
      expect(log.find{ |x| x =~ /reference: \d+\.\d+ms/ }).not_to be_nil
      expect(log.find{ |x| x =~ /your branch: \d+\.\d+ms/ }).not_to be_nil
      expect(log.find{ |x| x =~ /change: [+-]\d+\.\d+ms/ }).not_to be_nil
    end
  end

  describe "--json /posts" do
    it "should emit valid json on stdout" do
      out = perf_check("--json", "/posts")
      expect{ out = JSON.parse(out) }.not_to raise_error

      expect(out.class).to eq(Array)
      expect(out.size).to eq(1)

      result = out[0]
      expect(result["route"]).to eq("/posts")
      expect(result["latency"]).not_to be_nil
      expect(result["query_count"]).not_to be_nil
      expect(result["requests"].class).to eq(Array)
      expect(result["requests"].size).to eq(20)
      expect(result["reference_latency"]).not_to be_nil
      expect(result["latency_difference"]).not_to be_nil
      expect(result["speedup_factor"]).not_to be_nil
      expect(result["reference_query_count"]).not_to be_nil
      expect(result["reference_requests"].class).to eq(Array)
      expect(result["reference_requests"].size).to eq(20)

      req = result["requests"][0]
      expect(req["latency"]).not_to be_nil
      expect(req["query_count"]).not_to be_nil
      expect(req["server_memory"]).not_to be_nil
      expect(req["response_code"]).not_to be_nil
      expect(req["miniprofiler_url"]).not_to be_nil

      req = result["reference_requests"][0]
      expect(req["latency"]).not_to be_nil
      expect(req["query_count"]).not_to be_nil
      expect(req["server_memory"]).not_to be_nil
      expect(req["response_code"]).not_to be_nil
      expect(req["miniprofiler_url"]).not_to be_nil
    end
  end
end
