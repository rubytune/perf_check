require 'shellwords'

class PerfCheck
  class Git
    class NoSuchBranch < Exception; end
    class StashError < Exception; end
    class StashPopError < Exception; end
    class BundleError < Exception; end

    attr_reader :perf_check, :git_root, :current_branch

    def initialize(perf_check)
      @perf_check = perf_check
      @git_root = perf_check.app_root
      @current_branch = perf_check.options.branch || detect_current_branch
    end

    def logger
      @perf_check.logger
    end

    def checkout(branch, bundle_after_checkout: true, hard_reset: false)
      logger.info("Checking out #{branch} and bundling... ")
      PerfCheck.execute(
        checkout_command(branch, hard_reset: hard_reset),
        fail_with: NoSuchBranch
      )
      update_submodules
      bundle if bundle_after_checkout
    end

    def stash_if_needed
      if anything_to_stash?
        logger.info("Stashing your changes... ")
        PerfCheck.execute('git stash -q >/dev/null', fail_with: StashError)
        @stashed = true
      else
        false
      end
    end

    def stashed?
      !!@stashed
    end

    def anything_to_stash?
      git_stash = PerfCheck.execute('git diff')
      git_stash << PerfCheck.execute('git diff --staged')
      !git_stash.empty?
    end

    def pop
      logger.info("Git stash applying...")
      PerfCheck.execute('git stash pop -q', fail_with: StashPopError)
      @stashed = false
    end

    def migrations_to_run_down
      current_migrations_not_on_master.map do |filename|
        File.basename(filename, '.rb').split('_').first
      end
    end

    def clean_db
      PerfCheck.execute('git checkout db')
    end

    private

    def checkout_command(branch, hard_reset: false)
      if hard_reset
        "git fetch && git reset --hard origin/#{branch}"
      else
        "git checkout #{branch}"
      end
    end

    def detect_current_branch
      PerfCheck.execute('git rev-parse --abbrev-ref HEAD').strip
    end

    def update_submodules
      PerfCheck.execute('git submodule update')
    end

    def bundle
      Bundler.with_original_env do
        PerfCheck.execute(
          'bundle', 'install', '--frozen', '--retry', '3', '--jobs', '3',
          fail_with: BundleError
        )
      end
    end

    def current_migrations_not_on_master
      return [] unless File.exist?('db/migrate')

      PerfCheck.execute(
        'git diff master --name-only --diff-filter=A db/migrate/'
      ).split.reverse
    end
  end
end
