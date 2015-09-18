
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
        $stderr.puts
        Git.checkout_current_branch(false)
      end
    end

    def self.checkout_current_branch(bundle=true)
      checkout(@current_branch, bundle)
    end

    def self.checkout(branch, bundle=true)
      $stderr.print "Checking out #{branch} and bundling... "
      `git checkout #{branch} --quiet`
      abort "Problem with git checkout! Bailing..." unless $?.success?
      if bundle
        Bundler.with_clean_env{ `bundle` }
        abort "Problem bundling! Bailing..." unless $?.success?
      end
    end

    def self.stash_if_needed
      if anything_to_stash?
        $stderr.print("Stashing your changes... ")
        system('git stash -q >/dev/null')
        abort("Problem with git stash! Bailing...") unless $?.success?
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
      warn("Git stash applying...")
      system('git stash pop -q')
      abort("Problem with git stash! Bailing...") unless $?.success?
    end
  end

  def self.normalize_resource(resource)
    resource.sub(/^([^\/])/, '/\1')
  end
end
