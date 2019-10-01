# Test applications

PerfCheck uses compressed archives with Rails applications to test itself. You can find these bundles in `spec/bundles` and also referenced in the spec setup.

The contents of these bundles are a ‘regular’ Rails application plus a few extras.

## Git repository

The bundles have to include a *git* repository with a few twists.

    git init .

PerfCheck expects a remote so we add the repository as its own remote.

    git remote add origin .

Then you have make sure add all files and create branches if you want to test something specific.

## Ignore /perf_check

Make sure you ignore `/perf_check` in the repository because the PerfCheck test suite will create a symlink back to the working directory so the most recent version of PerfCheck can be loaded.

    # Used to symlink the current Perf Check working directory.
    /perf_check

## Add PerfCheck to the Gemfile

The Gemfile of the Rails app can optionally include the `perf_check` dependency. If you add it as a dependency you will need to do it in the following way:

    gem 'perf_check', path: 'perf_check'

Don't forget to run `bundle update` in the following way:

    ln -s ~/Code/perf_check
    bundle update
    rm perf_check

## Create the bundle

Make sure you are in the root of the Rails app and do the following.

    tar -cjf name.tar.bz2 .

You can ignore the warning about not including itself.