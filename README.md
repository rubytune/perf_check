## usage notes

`perf_check` launches a `rails server` in development mode to perform the benchmarks.

**Do not edit the working tree while `perf_check` is running!** This program performs git checkouts and stashes, which are undone after the benchmark completes. If the working tree changes after the reference commit is checked out, numerous problems may arise.

## application interface
`ENV['PERF_CHECK']` is set inside the server used to perform the benchmarks. The `perf_check` command also loads an instance of the application, separate from the server used to provide the benchmark.

#### benchmarking resources which require authorization

To enable benchmarking routes that require authorization, the rails app should provide a block to `PerfCheck::Server.authorization` that returns a cookie suitable for access to the route. For example:

```Ruby
# config/initializers/perf_check.rb
if defined?(PerfCheck)
  PerfCheck::Server.authorization do |login, route|
      session = { :user_id => 1, :sesssion_id => '1234' }
      PerfCheck::Server.sign_cookie_data('_notes_session', session)
  end
end
```

Note that this logic depends greatly on your rails configuration. In this example we have assumed that the app uses an unencryped CookieStore to hold session data, and has a simple authorization filter such as

```Ruby
   before_filter :authorize
   def authorize
      return false unless session[:session_id]
      @user = User.find(session[:session_id])
   end
```

Alternatively, you can provide a block to `PerfCheck::Server.authorization_action`, which will replace the login action of your app with the given block. Requests will be made to this action when a session cookie is required. For example, for an app with `post '/login', :to => 'application#login'`, you could have:

```Ruby
# config/initializers/perf_check.rb
if ENV['PERF_CHECK']
   PerfCheck::Server.authorization_action(:post, '/login') do |login, route|
      session[:user_id] = User.find_by_login(login).id
   end
end
```

The `login` parameter to the authorization block is one of

  1. `:super`
  2. `:admin`
  3. `:standard`
  4. A user name, passed in as a string (corresponding to the `-u` command line argument)

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

## example usage
```
$ perf_check -r HEAD -n5 /notes/browse 2>/dev/null
=============================================================================
PERRRRF CHERRRK! Grab a coffee and don't touch your working tree (we automate git)
=============================================================================


Benchmarking /notes/browse:
	Request  1: 774.8ms	  66MB
	Request  2: 773.4ms	  66MB
	Request  3: 771.1ms	  66MB
	Request  4: 774.1ms	  66MB
	Request  5: 773.7ms	  67MB



Benchmarking /notes/browse:
	Request  1: 20.2ms	  68MB
	Request  2: 23.0ms	  68MB
	Request  3: 19.9ms	  68MB
	Request  4: 19.5ms	  69MB
	Request  5: 19.4ms	  69MB

==== Results ====
/notes/browse
       master: 20.4ms
  your branch: 773.4ms
       change: +753.0ms (yours is 37.9x slower!!!)
```
