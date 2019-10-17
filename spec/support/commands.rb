# frozen_string_literal: true

require 'open3'

module Support
  # Helpers to execute commands in a shell
  module Commands
    # Wrapper to safely execute commands in specs.
    def execute(*args, **kwargs)
      output, status = Open3.capture2e(*args, **kwargs)
      raise output unless status.success?
      output
    end

    def git(*args)
      execute('git', *args)
    end

    def bundle(*args)
      Bundler.with_clean_env do
        execute('bundle', *args)
      end
    end
  end
end
