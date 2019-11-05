# frozen_string_literal: true

require 'tmpdir'

module Support
  # Helpers for working with paths in the test suite.
  module Paths
    # Yields a temporary directory and automatically cleans it up when the
    # block ends.
    def using_tmpdir(&block)
      Dir.mktmpdir('perf-check', &block)
    end

    # Returns the root directory if the source code.
    def perf_check_project_root
      File.expand_path('../../', __dir__)
    end
  end
end
