require 'spec_helper'

RSpec.describe PerfCheck::TestCase do
  let(:test_case) do
    PerfCheck::TestCase.new(double(), '/xyz')
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
