
require 'spec_helper'
require 'perf_check/middleware'

module Rails
  def self.root
    "tmp/spec"
  end
end

module ActiveSupport
  module Notifications
    def self.subscribe(*args)
    end
  end
end

RSpec.describe PerfCheck::Middleware do
  let(:middleware){ PerfCheck::Middleware.new(double) }
  let(:env){ double }

  describe "#call" do
    it "should insert X-PerfCheck-Query-Count header" do
      expect(middleware.app).to receive(:call).with(env){ [200, {}, ''] }
      status, headers, body = middleware.call(env)

      expect(headers['X-PerfCheck-Query-Count']).to match(/^[0-9]+$/)
    end

    context "when backend raises exception" do
      it "should insert X-PerfCheck-StackTrace header with path to backtrace" do
        expect(middleware.app).to receive(:call).with(env){ raise NoMethodError.new }
        status, headers, body = middleware.call(env)

        expect(headers['X-PerfCheck-StackTrace']).to match(/^#{Rails.root}/)
      end
    end
  end
end
