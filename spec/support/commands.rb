# frozen_string_literal: true

require 'open3'

module Support
  # Helpers to execute commands in a shell
  module Commands
    # Wrapper to safely execute commands in specs.
    def execute(*args, **kwargs)
      output, status = Open3.capture2e(*args, **kwargs)
      raise PerfCheck::App::PackError, output unless status.exitstatus.zero?
      output
    end
  end
end
