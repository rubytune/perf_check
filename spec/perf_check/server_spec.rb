# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PerfCheck::Server do
  let(:output) { StringIO.new }
  let(:perf_check) do
    perf_check = PerfCheck.new(Dir.pwd)
    perf_check.logger = Logger.new(output)
    perf_check
  end
  let(:server) { PerfCheck::Server.new(perf_check) }

  describe 'setup' do
    it 'uses basic environment variables' do
      expect(server.environment_variables).to eq(
        'PERF_CHECK' => '1',
        'DISABLE_SPRING' => '1'
      )
    end

    it 'sets an additional environment variable when only verifying' do
      # Settings this option instructs PerfCheck to only measure the
      # experimental branch. It will not measure and compare the difference
      # to another branch.
      perf_check.options.verify_no_diff = true
      expect(server.environment_variables).to eq(
        'PERF_CHECK' => '1',
        'DISABLE_SPRING' => '1',
        'PERF_CHECK_VERIFICATION' => '1'
      )
    end

    it 'sets an additional environment variable when chaching is off' do
      perf_check.options.caching = false
      expect(server.environment_variables).to eq(
        'PERF_CHECK' => '1',
        'DISABLE_SPRING' => '1',
        'PERF_CHECK_NOCACHING' => '1'
      )
    end

    it 'runs in the development environment by default' do
      expect(server.environment).to eq('development')
    end

    it 'will start in the configured environment' do
      perf_check.options.environment = 'production'
      expect(server.environment).to eq('production')
    end

    it 'generates a sensible rails server command' do
      expect(server.rails_server_command).to eq(
        'bundle exec rails server -b 127.0.0.1 -d -p 3031 -e development'
      )
    end
  end

  describe 'system' do
    it 'does not return a PID when not running' do
      expect(server.pid).to be_nil
    end

    it 'measures zero memory when not running' do
      # This spec might not be the actual behavior we want, but it's what
      # the formatters currently expect.
      expect(server.mem).to be_zero
    end
  end

  context 'operating on an actual Rails app' do
    around do |example|
      using_app('minimal') do
        run_bundle_install
        example.run
      end
    end

    # Even though the apps are 'isolated', they are still triggered from a
    # process with an environment that interferes Bundler and Ruby. On CI,
    # just like on certain deployments, this means we can't start a server
    # unless we use a fresh environment. Skip this spec on CI to work around
    # this.
    it 'starts a server', skip_on_ci: true do
      begin
        server.start
        expect(server.running?).to be true
        expect(server.pid).to_not be_nil
        expect(server.mem).to_not be_zero
      ensure
        server.exit
      end
    end

    it 'starts a server in a fresh shell environment' do
      perf_check.options.spawn_shell = true
      begin
        server.start
        expect(server.running?).to be true
        expect(server.pid).to_not be_nil
        expect(server.mem).to_not be_zero
      ensure
        server.exit
      end
    end

    # On CI the first request against the target application returns a 500
    # Internal Server error so we need to perform multiple request.
    it 'profiles' do
      perf_check.options.spawn_shell = true
      begin
        server.start

        profile = nil
        2.times do
          profile = server.profile do |http|
            http.get('/', {})
          end
        end

        expect(profile.response_code).to eq(200)
        expect(profile.response_body).to eq('Hi!')
        expect(profile.query_count).to be_zero
        expect(profile.latency).to_not be_zero
        expect(profile.server_memory).to_not be_zero
        expect(profile.profile_url).to be_nil
      ensure
        server.exit
      end
    end
  end
end
