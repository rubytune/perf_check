require 'shellwords'

class PerfCheck
  class Git
    class NoSuchBranch < Exception; end
    class StashError < Exception; end
    class StashPopError < Exception; end
    class BundleError < Exception; end

    attr_reader :perf_check, :git_root, :current_branch
    attr_accessor :logger

    def initialize(perf_check)
      @perf_check = perf_check
      @git_root = perf_check.app_root
      @logger = perf_check.logger

      @current_branch = exec "git rev-parse --abbrev-ref HEAD"
    end

    def checkout(branch, bundle_after_checkout: true, hard_reset: false)
      logger.info("Checking out #{branch} and bundling... ")
      if hard_reset
        exec "git fetch --quiet && git reset --hard origin/#{branch} --quiet"
      else
        exec "git checkout #{branch} --quiet"
      end

      unless $?.success?
        logger.fatal("Problem with git checkout! Bailing...")
        raise NoSuchBranch
      end

      update_submodules
      bundle if bundle_after_checkout
    end

    def stash_if_needed
      if anything_to_stash?
        logger.info("Stashing your changes... ")
        exec "git stash -q >/dev/null"

        unless $?.success?
          logger.fatal("Problem with git stash! Bailing...")
          raise StashError
        end

        @stashed = true
      end
    end

    def stashed?
      !!@stashed
    end

    def anything_to_stash?
      git_stash = exec "git diff"
      git_stash << exec("git diff --staged")
      !git_stash.empty?
    end

    def pop
      logger.info("Git stash applying...")
      exec "git stash pop -q"

      unless $?.success?
        logger.fatal("Problem with git stash! Bailing...")
        raise StashPopError
      end
    end

    def migrations_to_run_down
      current_migrations_not_on_master.map do |filename|
        File.basename(filename, '.rb').split('_').first
      end
    end

    def clean_db
      exec "git checkout db"
    end

    private

    def update_submodules
      exec "git submodule update --quiet"
    end

    def bundle
      Bundler.with_clean_env{ exec "bundle" }
      unless $?.success?
        logger.fatal("Problem bundling! Bailing...")
        raise BundleError
      end
    end

    def current_migrations_not_on_master
      exec("git diff master --name-only --diff-filter=A db/migrate/").
        split.reverse
    end

    def exec(command)
      root = Shellwords.shellescape(git_root)
      `cd #{root} && #{command}`.strip
    end
  end
end
