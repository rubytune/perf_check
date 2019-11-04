require 'shellwords'

class PerfCheck
  class Git
    class NoSuchBranch < Exception; end
    class StashError < Exception; end
    class StashPopError < Exception; end

    attr_reader :perf_check, :git_root
    attr_reader :initial_branch

    def initialize(perf_check)
      @perf_check = perf_check
      @git_root = perf_check.app_root
      @initial_branch = detect_current_branch
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
      PerfCheck.bundle if bundle_after_checkout
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

    def detect_current_branch
      branch = PerfCheck.execute('git rev-parse --abbrev-ref=loose HEAD').strip
      return branch unless branch == 'HEAD'

      # When the current ref is abbreviated to HEAD it's pretty useless because
      # it will not allow us to reliably switch to this ref at a later time. The
      # solution is to not abbreviate.
      PerfCheck.execute('git rev-parse HEAD').strip
    end

    private

    def checkout_command(branch, hard_reset: false)
      if hard_reset
        "git fetch && git reset --hard origin/#{branch}"
      else
        "git checkout #{branch}"
      end
    end

    def update_submodules
      PerfCheck.execute('git submodule update')
    end

    def current_migrations_not_on_master
      return [] unless File.exist?('db/migrate')

      PerfCheck.execute(
        'git diff master --name-only --diff-filter=A db/migrate/'
      ).split.reverse
    end
  end
end
