## usage
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
