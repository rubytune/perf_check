require 'shellwords'

class PerfCheck
  class Git
    attr_reader :perf_check, :git_root, :current_branch
    attr_accessor :logger

    def initialize(perf_check)
      @perf_check = perf_check
      @git_root = perf_check.app_root
      @logger = perf_check.logger

      root = Shellwords.shellescape(git_root)
      @current_branch = `cd #{root} && git rev-parse --abbrev-ref HEAD`.strip
    end

    def checkout_reference(reference='master')
      checkout(reference)
      at_exit do
        logger.info ''
        checkout_current_branch(false)
      end
    end

    def checkout_current_branch(bundle=true)
      checkout(@current_branch, bundle)
    end

    def checkout(branch, bundle=true)
      logger.info("Checking out #{branch} and bundling... ")
      `git checkout #{branch} --quiet`

      unless $?.success?
        logger.fatal("Problem with git checkout! Bailing...") && abort
      end

      `git submodule update --quiet`

      if bundle
        Bundler.with_clean_env{ `bundle` }
        unless $?.success?
          logger.fatal("Problem bundling! Bailing...") && abort
        end
      end
    end

    def stash_if_needed
      if anything_to_stash?
        logger.info("Stashing your changes... ")
        system('git stash -q >/dev/null')

        unless $?.success?
          logger.fatal("Problem with git stash! Bailing...") && abort
        end

        at_exit do
          pop
        end
      end
    end

    def anything_to_stash?
      git_stash = `git diff`
      git_stash << `git diff --staged`
      !git_stash.empty?
    end

    def pop
      logger.info("Git stash applying...")
      system('git stash pop -q')

      unless $?.success?
        logger.fatal("Problem with git stash! Bailing...") && abort
      end
    end

    def migrations_to_run_down
      current_migrations_not_on_master.map { |filename| File.basename(filename, '.rb').split('_').first }
    end

    def clean_db
      `git checkout db`
    end

    private

    def current_migrations_not_on_master
      %x{git diff origin/master --name-only --diff-filter=A db/migrate/}.split.reverse
    end
  end
end
