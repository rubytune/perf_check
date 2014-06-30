## usage notes

`perf_check` launches a `rails server` in development mode to perform the benchmarks.

**Do not edit the working tree while `perf_check` is running!** This program performs git checkouts and stashes, which are undone after the benchmark completes. If the working tree changes after the reference commit is checked out, numerous problems may arise.

## application interface
`ENV['PERF_CHECK']` is set inside the server used to perform the benchmarks.

The `perf_check` command also loads an instance of the application, separate from the server used to provide the benchmark. To enable benchmarking routes that require authorization, the rails app should provide a block to `PerfCheck::Server.authorization` that returns a cookie suitable for access to the route. For example:


    # config/initializers/perf_check.rb
    if defined?(PerfCheck)
      PerfCheck::Server.authorization do |login, route|
          secret = Rails.application.config.secret_token
          marshal = ActiveSupport::MessageVerifier.new(secret, :serializer => Marshal)
          marshal_value = marshal.generate(:user_id => 1, :session_id => '1234')

          "_app_session=#{marshal_value}"
      end
    end

Note that this logic depends greatly on your rails configuration. In this example we have assumed that the app uses an unencryped CookieStore to hold session data.

The `login` parameter to the authorization block is one of

    1. :super
    2. :admin
    3. :standard
    4. A user name, passed in as a string.

It is up to the application to decide the semantics of this parameter.

The `route` parameter is a PerfCheck::TestCase. The block should return a cookie suitable for accessing `route.resource` (e.g. /users/1/posts) as the given `login`.

## command line usage
    Usage: perf_check [options] [route ...]
    Login options:
            --admin                      Log in as admin user for route
            --standard                   Log in as standard user for route
            --super                      Log in as super user
        -u, --user USER                  Log in as USER
        -L, --no-login                   Don't log in

    Benchmark options:
        -n, --requests N                 Use N requests in benchmark, defaults to
        -r, --reference COMMIT           Benchmark against COMMIT instead of master
        -q, --quick                      Fire off 5 requests just on this branch, no comparison with master

    Usage examples:
      Benchmark PostController#index against master
         perf_check /user/45/posts
         perf_check /user/45/posts -n5
         perf_check /user/45/posts --standard

      Benchmark against a specific commit
         perf_check /user/45/posts -r 0123abcdefg
         perf_check /user/45/posts -r HEAD~2

      Benchmark the changes in the working tree
         perf_check /user/45/posts -r HEAD