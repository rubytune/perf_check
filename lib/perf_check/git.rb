
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
        puts
        Git.checkout_current_branch
      end
    end

    def self.checkout_current_branch
      checkout(@current_branch)
    end

    def self.checkout(branch)
      print "Checking out #{branch}... "
      `git checkout #{branch} --quiet`
      puts "Problem with git checkout! Bailing..." and exit(1) unless $?.success?
    end

    def self.stash_if_needed
      if anything_to_stash?
        print("Stashing your changes... ")
        system('git stash -q >/dev/null')
        puts("Problem with git stash! Bailing...") and exit(1) unless $?.success?
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
      puts("Git stash applying...")
      system('git stash pop -q')
      puts("Problem with git stash! Bailing...") and exit(1) unless $?.success?
    end
  end

  def self.normalize_resource(resource)
    resource.sub(/^([^\/])/, '/\1')
  end
end
