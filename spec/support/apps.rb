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

    # Unpacks an app, changes directory to that app, and calls the block.
    def using_app(name, &block)
      using_tmpdir do |app_dir|
        PerfCheck::App.new(
          bundle_path: app_bundle_path(name),
          app_dir: app_dir
        ).unpack
        Dir.chdir(app_dir, &block)
      end
    end
  end
end
