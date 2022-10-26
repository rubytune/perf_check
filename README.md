# ⚠ THIS PROJECT HAS BEEN ARCHIVED ⚠

![](https://api.travis-ci.org/rubytune/perf_check.svg)
## What is perf check

`perf_check` is a quick-n-dirty way to benchmark branches of your rails app.

Imagine a rails-aware [apache ab](http://httpd.apache.org/docs/2.2/programs/ab.html).

We typically run it locally or on staging, to get a general idea of how our branches might have affected app performance. Often, certain pages render differently if logged in, or as an admin, so `perf_check` provides an easy way to deal with that.

## How to install

Add it to your Gemfile, probably just in the `:development` group

```
gem 'perf_check'
```

You will actually have to commit this. Preferably to master, which will make life easiest. Basically, as long as the gem exists on whatever reference branch you are benchmarking against, you are good to go.

## How to use

In it's simplest incarnation, just feed an url to it

```
$ bundle exec perf_check /notes/browse
=============================================================================
PERRRRF CHERRRK! Grab a coffee and don't touch your working tree (we automate git)
=============================================================================


Benchmarking /notes/browse:
	Request  1:  774.8ms	  66MB
	Request  2:  773.4ms	  66MB
	Request  3:  771.1ms	  66MB
	Request  4:  774.1ms	  66MB
	Request  5:  773.7ms	  66MB
	Request  6:  774.8ms	  66MB
	Request  7:  773.4ms	  66MB
	Request  8:  771.1ms	  66MB
	Request  9:  774.1ms	  66MB
	Request  10: 773.7ms	  67MB

Benchmarking /notes/browse:
	Request  1:  20.2ms	  68MB
	Request  2:  23.0ms	  68MB
	Request  3:  19.9ms	  68MB
	Request  4:  19.5ms	  68MB
	Request  5:  19.4ms	  68MB
	Request  6:  20.2ms	  68MB
	Request  7:  23.0ms	  68MB
	Request  8:  19.9ms	  68MB
	Request  9:  19.5ms	  69MB
	Request  10: 19.4ms	  69MB

==== Results ====
/notes/browse
       master: 20.4ms
  your branch: 773.4ms
       change: +753.0ms (yours is 37.9x slower!!!)
```

## How does it work

In the above example, `perf_check`

* Launches its own rails server on a custom port (WITH CACHING FORCE-ENABLED)
* Hits /user/45/posts 11 times (throws away the first request)
* Git stashes in case you have uncommitted stuff. Checks out master. Restarts server
* Hits /user/45/posts 11 times (throws away the first request)
* Applies the stash if it existed
* Prints results

## Caveats of DOOOOM

### We automate git

**Do not edit the working tree while `perf_check` is running!**

This program performs git checkouts and stashes, which are undone after the benchmark completes. If the working tree changes after the reference commit is checked out, numerous problems may arise.

### Caching is forced on (by default)

Perf check start ups its rails server with `cache_classes=true` and `perform_caching=true` regardless of what's in your development.rb

You can pass `--clear-cache` which will run `Rails.cache.clear` before each batch of requests. This is useful when testing caching.

## All options
```
$ bundle exec perf_check
Usage: perf_check [options] [route ...]
Benchmark options:
    -n, --requests N                 Use N requests in benchmark, defaults to 10
    -r, --reference COMMIT           Benchmark against COMMIT instead of master
    -q, --quick                      Fire off 5 requests just on this branch, no comparison with master
        --clear-cache                Call Rails.cache.clear before running benchmark
        --302-success                Consider HTTP 302 code a successful request
        --302-failure                Consider HTTP 302 code an unsuccessful request
        --run-migrations             Run migrations up and down with branch

Usage examples:
  Benchmark PostController#index against master
     perf_check /user/45/posts
     perf_check /user/45/posts -n5

  Benchmark against a specific commit
     perf_check /user/45/posts -r 0123abcdefg
     perf_check /user/45/posts -r HEAD~2

  Benchmark the changes in the working tree
     perf_check /user/45/posts -r HEAD

  Benchmark and diff the output against master
     perf_check /user/45/posts --verify-no-diff

  Diff the output on your branch with master
     perf_check /user/45/posts --diff

  Diff a bunch of urls listed in a file (newline seperated)
     perf_check --diff --input FILE
```

## Troubleshooting


### Perf Check

Setting the `PERF_CHECK` env variable will start up your app with the [middleware](https://github.com/rubytune/perf_check/blob/master/lib/perf_check/middleware.rb) which does things like capture backtraces and count sql queries

```
PERF_CHECK=true bundle exec rails s
```

### Redis

Certain versions of redis might need the following snippet to fork properly:

```
  # Circumvent redis forking issues with our version of redis
  # Will be fixed when we update redis https://github.com/redis/redis-rb/issues/364
  class Redis
    class Client
      def ensure_connected
        tries = 0
        begin
          if connected?
            if Process.pid != @pid
              reconnect
            end
          else
            connect
          end
          tries += 1
          yield
        rescue ConnectionError
          disconnect
          if tries < 2 && @reconnect
            retry
          else
            raise
          end
        rescue Exception
          disconnect
          raise
        end
      end
    end
  end
  ```
