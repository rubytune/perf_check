require 'spec_helper'

RSpec.describe PerfCheck::TestCase do
  let(:test_case) do
    PerfCheck::TestCase.new(double(options: double(headers: {})), '/xyz')
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
