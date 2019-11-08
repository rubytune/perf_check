# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PerfCheck::VERSION do
  it 'returns a reasonable version' do
    expect(
      Gem::Version.new(PerfCheck::VERSION)
    ).to be > Gem::Version.new('0.1.0')
  end
end
