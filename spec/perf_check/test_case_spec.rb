require 'spec_helper'

RSpec.describe PerfCheck::TestCase do
  let(:test_case) do
    system("mkdir", "-p", "tmp/spec/app")
    perf_check = PerfCheck.new('tmp/spec/app')
    perf_check.logger = Logger.new('/dev/null')
    PerfCheck::TestCase.new(perf_check, '/xyz')
  end

  describe "#issue_request(server, options)" do
    it "should issue its request inside the server.profile wrapper and return that result" do
      server = double(profile: nil)
      result = double(response_code: 200)
      options = double(http_statuses: [200])
      expect(server).to receive(:profile){ result }

      expect(test_case.issue_request(server, options)).to eq(result)
    end

    it "should raise UnexpectedHttpResponse if the http response is not allowed" do
      server = double(profile: nil)
      result = double(response_code: 302)
      options = double(http_statuses: [200])
      expect(server).to receive(:profile){ result }

      expect{ test_case.issue_request(server, options) }.
        to raise_error(PerfCheck::TestCase::UnexpectedHttpResponse)
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

  describe "#response_for_comparison(body)" do
    it "should save body in (this|reference)_responsedepending on switch_to_reference_context" do
      test_case.response_for_comparison('abcdef')
      test_case.switch_to_reference_context
      test_case.response_for_comparison('uvwxyz')

      expect(test_case.this_response).to eq('abcdef')
      expect(test_case.reference_response).to eq('uvwxyz')
    end
  end

  describe "#context_profiles" do
    it "should be #this_profiles until switch_to_reference_context is called" do
      expect(test_case.context_profiles.object_id).
        to eq(test_case.this_profiles.object_id)

      test_case.switch_to_reference_context

      expect(test_case.context_profiles.object_id).
        to eq(test_case.reference_profiles.object_id)
    end
  end
end
