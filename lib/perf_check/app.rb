# frozen_string_literal: true

require 'open3'
require 'shellwords'

class PerfCheck
  # Packs and unpacks Rails projects using tarballs.
  #
  #   PerfCheck::App.new(
  #     bundle_path: '/path/to/my.tar.bz2',
  #     app_dir: '/tmp/perf-check/my'
  #   ).unpack
  #
  # It raises PackError, a subclass of RuntimeError, when anything goes wrong.
  class App
    class PackError < ::RuntimeError; end

    attr_reader :bundle_path
    attr_reader :app_dir

    def initialize(bundle_path:, app_dir:)
      @bundle_path = bundle_path
      @app_dir = app_dir
    end

    def pack
      execute('tar', '-cjf', bundle_path, '.', '.git', chdir: app_dir)
    end

    def unpack
      execute('tar', '-xjf', bundle_path, '-C', app_dir)
    end

    private

    def execute(*args, **kwargs)
      output, status = Open3.capture2e(*args, **kwargs)
      raise PerfCheck::App::PackError, output unless status.exitstatus.zero?
    end
  end
end
