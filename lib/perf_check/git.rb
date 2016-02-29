
class PerfCheck
  class Git
    # the branch we are on while loading the script
    @current_branch = `git rev-parse --abbrev-ref HEAD`.strip

    def self.current_branch
      @current_branch
    end

    def self.checkout_reference(reference='master')
      checkout(reference)
      at_exit do
        logger.info ''
        Git.checkout_current_branch(false)
      end
    end

    def self.checkout_current_branch(bundle=true)
      checkout(@current_branch, bundle)
    end

    def self.checkout(branch, bundle=true)
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

    def self.stash_if_needed
      if anything_to_stash?
        logger.info("Stashing your changes... ")
        system('git stash -q >/dev/null')

        unless $?.success?
          logger.fatal("Problem with git stash! Bailing...") && abort
        end

        at_exit do
          Git.pop
        end
      end
    end

    def self.anything_to_stash?
      git_stash = `git diff`
      git_stash << `git diff --staged`
      !git_stash.empty?
    end

    def self.pop
      logger.info("Git stash applying...")
      system('git stash pop -q')

      unless $?.success?
        logger.fatal("Problem with git stash! Bailing...") && abort
      end
    end

    def self.migrations_to_run_down
      current_migrations_not_on_master.map { |filename| File.basename(filename, '.rb').split('_').first }
    end

    def self.current_migrations_not_on_master
      %x{git diff origin/master --name-only --diff-filter=A db/migrate/}.split.reverse
    end
    private_class_method :current_migrations_not_on_master
  end
end
