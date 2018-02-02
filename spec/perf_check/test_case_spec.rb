require 'spec_helper'

RSpec.describe PerfCheck::TestCase do
  let(:test_case) do
    system("mkdir", "-p", "tmp/spec/app")
    perf_check = PerfCheck.new('tmp/spec/app')
    perf_check.logger = Logger.new('/dev/null')
    PerfCheck::TestCase.new(perf_check, '/xyz')
  end

  after(:all) do
    FileUtils.rm_rf('tmp/spec')
  end

  describe "#run(server, options)" do
    let(:server){ double() }
    let(:options){ OpenStruct.new(number_of_requests: 3, http_statuses: [200]) }
    let(:profile) do
      # need these fields or else logging fails
      OpenStruct.new(latency: 0, server_memory: 0,
                     response_code: 200, query_count: 0,
                     profile_url: '', response_body: 'abcdef')
    end

    it "should issue_request options.number_of_requests + 2 times" do
      expect(test_case).to receive(:issue_request){ profile }.
                            with(server, options).exactly(5).times
      test_case.run(server, options)
    end

    it "should add a options.number_of_requests profiles to profiles array" do
      allow(test_case).to receive(:issue_request){ profile }
      expect(test_case.this_profiles).to receive(:<<).with(profile).
                                          exactly(options.number_of_requests).times
      test_case.run(server, options)

      test_case.switch_to_reference_context
      expect(test_case.reference_profiles).to receive(:<<).with(profile).
                                               exactly(options.number_of_requests).times
      test_case.run(server, options)
    end

    it "should stop issuing requests if an unexpected response code is returned" do
      i = 0
      allow(test_case).to receive(:issue_request) do
        profile.response_code = [200, 200, 200, 500, 200][i]
        i = i + 1
        profile.dup
      end

      test_case.run(server, options)

      expect(test_case.this_profiles.size).to eq(2)
      expect(test_case.this_profiles[0].response_code).to eq(200)
      expect(test_case.this_profiles[1].response_code).to eq(500)
    end

    context "options.verify_no_diff" do
      it "should save response bodies to this_response and reference_response" do
        options.verify_no_diff = true
        allow(test_case).to receive(:issue_request){ profile }

        profile.response_body = 'abcdef'
        test_case.run(server, options)

        test_case.switch_to_reference_context
        profile.response_body = 'uvwxyz'
        test_case.run(server, options)

        expect(test_case.this_response).to eq('abcdef')
        expect(test_case.reference_response).to eq('uvwxyz')
      end
    end
  end

  describe "#issue_request(server, options)" do
    it "should issue its request inside the server.profile wrapper and return that result" do
      server = double(profile: nil)
      result = double(response_code: 200)
      options = double(http_statuses: [200])
      expect(server).to receive(:profile){ result }

      expect(test_case.issue_request(server, options)).to eq(result)
    end
  end

  describe "#request_headers" do
    it "should include Cookie: test_case.cookie" do
      test_case.cookie = 'abcdef'
      expect(test_case.request_headers['Cookie']).to eq('abcdef')
    end

    it "should include Accept" do
      expect(test_case.request_headers['Accept']).to match(/\btext\/html\b/)
    end

    it "should merge perf_check.options.headers" do
      test_case.perf_check.options.headers['X-Spec-Custom'] = 'abcdef'
      expect(test_case.request_headers['X-Spec-Custom']).to eq('abcdef')
    end
  end

  context "options.verify_no_diff" do
    describe "#response_diff" do
      it "should return a struct with #changed?, and #file if changed" do
        expect(test_case).to receive(:this_response){ "abc\n" }
        expect(test_case).to receive(:reference_response){ "xyz\n" }

        diff = test_case.response_diff
        expect(diff.changed?).to eq(true)
        expect(File.read(diff.file)).to eq("@@ -1 +1 @@\n-xyz\n+abc\n")


        expect(test_case).to receive(:this_response){ "hij\n" }
        expect(test_case).to receive(:reference_response){ "hij\n" }

        diff = test_case.response_diff
        expect(diff.changed?).to eq(false)
        expect(diff.file).to be_nil
      end

      it "should show 3 lines of context by default" do
        expect(test_case).to receive(:this_response){ "a\nb\nc\nd\nabc\ne\nf\ng\nh" }
        expect(test_case).to receive(:reference_response){"a\nb\nc\nd\nxyz\ne\nf\ng\nh"}

        diff = test_case.response_diff
        expect(diff.changed?).to eq(true)
        expect(File.read(diff.file)).to eq("@@ -2,7 +2,7 @@\n b\n c\n d\n-xyz\n+abc\n e\n f\n g\n")
      end

      it "should by default ignore mini-profiler lines" do
        expect(test_case).to receive(:this_response){
          %(<script src="/mini-profiler-resources/includes.js?v=abc"></script>)
        }
        expect(test_case).to receive(:reference_response){
          %(<script src="/mini-profiler-resources/includes.js?v=xyz"></script>)
        }

        expect(test_case.response_diff.changed?).to eq(false)
      end

      it "should respect perf_check.options.diff_options" do
        test_case.perf_check.options.diff_options.
          push("--ignore-matching-lines=foo bar")
        expect(test_case).to receive(:this_response){ "foo bar baz" }
        expect(test_case).to receive(:reference_response){ "foo bar bink" }

        expect(test_case.response_diff.changed?).to eq(false)
      end
    end
  end

  describe "stats methods" do
    before do
      test_case.this_profiles = (1..10).map do |x|
        double(latency: x, query_count: x)
      end
      test_case.reference_profiles = (10..20).map do |x|
        double(latency: x, query_count: x)
      end
    end

    describe "#(this|reference)_latency" do
      it "should be the average this/reference profiles latency" do
        expect(test_case.this_latency).to eq(5.5)
        expect(test_case.reference_latency).to eq(15.0)
      end
    end

    describe "#(this|reference)_query_count" do
      it "should be the average this/reference profiles query count" do
        expect(test_case.this_query_count).to eq(5)
        expect(test_case.reference_query_count).to eq(15.0)
      end
    end

    describe "#latency_difference" do
      it "should be the difference between this and reference latency" do
        expect(test_case.latency_difference).to eq(-9.5)
      end
    end

    describe "#speedup_factor" do
      it "should be the ratio of reference latency to this latency" do
        expect(test_case.speedup_factor.to_s[0, 4]).to eq("2.72")
      end
    end
  end

  describe "#response_diff" do
    it "should be the diff between response bodies on reference and this branch"
  end
end
