require 'shellwords'

class PerfCheck
  class Git
    class NoSuchBranch < Exception; end

    attr_reader :perf_check, :git_root, :current_branch
    attr_accessor :logger

    def initialize(perf_check)
      @perf_check = perf_check
      @git_root = perf_check.app_root
      @logger = perf_check.logger

      @current_branch = exec "git rev-parse --abbrev-ref HEAD"
    end

    def checkout_reference(reference='master')
      checkout(reference)
#      at_exit do
#        logger.info ''
#        checkout_current_branch(false)
#      end
    end

    def checkout_current_branch(bundle=true)
      checkout(@current_branch, bundle)
    end

    def checkout(branch, bundle=true)
      logger.info("Checking out #{branch} and bundling... ")
      exec "git checkout #{branch} --quiet"

      unless $?.success?
        logger.fatal("Problem with git checkout! Bailing...")
        raise NoSuchBranch
      end

      exec "git submodule update --quiet"

      if bundle
        Bundler.with_clean_env{ exec "bundle" }
        unless $?.success?
          logger.fatal("Problem bundling! Bailing...") && abort
        end
      end
    end

    def stash_if_needed
      if anything_to_stash?
        logger.info("Stashing your changes... ")
        exec "git stash -q >/dev/null"

        unless $?.success?
          logger.fatal("Problem with git stash! Bailing...") && abort
        end

#        at_exit do
#          pop
#        end
      end
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
        logger.fatal("Problem with git stash! Bailing...") && abort
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

    def current_migrations_not_on_master
      exec("git diff origin/master --name-only --diff-filter=A db/migrate/").
        split.reverse
    end

    def exec(command)
      root = Shellwords.shellescape(git_root)
      `cd #{root} && #{command}`.strip
    end
  end
end
