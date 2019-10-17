# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PerfCheck::App do
  it 'unpacks a bundled app' do
    using_tmpdir do |app_dir|
      PerfCheck::App.new(
        bundle_path: app_bundle_path('minimal'),
        app_dir: app_dir
      ).unpack

      expect(File.exist?(File.join(app_dir, 'Gemfile'))).to be true
      expect(File.exist?(File.join(app_dir, '.git'))).to be true
      expect(File.exist?(File.join(app_dir, '.gitignore'))).to be true
    end
  end

  it 'raises an exception when unpacking fails' do
    expect do
      PerfCheck::App.new(
        bundle_path: app_bundle_path('minimal'),
        app_dir: 'wrong'
      ).unpack
    end.to raise_error(PerfCheck::App::PackError)
  end

  it 'packs an app to a bundle' do
    using_tmpdir do |bundle_dir|
      target_bundle_path = File.join(bundle_dir, 'mine.tar.bz2')
      using_tmpdir do |app_dir|
        # Unpack the test app
        PerfCheck::App.new(
          bundle_path: app_bundle_path('minimal'),
          app_dir: app_dir
        ).unpack

        expect(File.exist?(app_dir)).to be true

        # Pack the unpacked test app
        PerfCheck::App.new(
          bundle_path: target_bundle_path,
          app_dir: app_dir
        ).pack

        expect(File.exist?(target_bundle_path)).to be true
        expect(File.size(target_bundle_path)).to be > 10_000

        using_tmpdir do |app2_dir|
          # Unpack the packed test app
          PerfCheck::App.new(
            bundle_path: target_bundle_path,
            app_dir: app2_dir
          ).unpack

          # After going back and forth packing and unpacking all the files
          # should be there.
          expect(File.exist?(File.join(app2_dir, 'Gemfile'))).to be true
          expect(File.exist?(File.join(app2_dir, '.git'))).to be true
          expect(File.exist?(File.join(app2_dir, '.gitignore'))).to be true
        end
      end
    end
  end

  it 'raises an exception when packing fails' do
    expect do
      using_tmpdir do |app_dir|
        PerfCheck::App.new(
          bundle_path: 'wrong',
          app_dir: app_dir
        ).unpack
      end
    end.to raise_error(PerfCheck::App::PackError)
  end
end
