# frozen_string_literal: true

module Support
  # Helpers to prepare app directories for integration testing.
  module Apps
    # Returns the directory that holds all the app bundles.
    def bundle_dir
      File.expand_path('../bundles', __dir__)
    end

    # Returns a path to a tarball for the specified bundle name.
    def app_bundle_path(name)
      File.join(bundle_dir, "#{name}.tar.bz2")
    end
  end
end
