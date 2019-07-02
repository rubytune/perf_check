require "optparse"
require "shellwords"

class PerfCheck
  def parse_arguments(argv)
    options.argv = argv.is_a?(String) ? Shellwords.shellsplit(argv) : argv
    option_parser.parse(options.argv).each do |route|
      add_test_case(route.strip)
    end
  end

  def option_parser
    @optparse ||= OptionParser.new do |opts|
      opts.banner = "Usage: perf_check [options] [route ...]"

      opts.separator "\nBenchmark options:"
      opts.on('--requests N', '-n',
        'Use N requests in benchmark, defaults to 20') do |n|
        options.number_of_requests = n.to_i
      end

      opts.on('--reference COMMIT', '-r',
        'Benchmark against COMMIT instead of master') do |commit|
        options.reference = commit
      end

      opts.on('--branch COMMIT', '-branch',
        'Set the current branch to benchmark against (defaults to the branch you currently have checked out)') do |branch|
        options.branch = branch
      end

      opts.on('--quick', '-q',
        '20 requests just on this branch (no comparison with master)') do
        options.reference = nil
      end

      opts.on('--compare-paths',
        'Compare two paths against each other on the same branch') do
        options[:compare_paths?] = true
      end

      opts.on('--302-success',
        'Consider HTTP 302 code a successful request') do
        options.http_statuses.push(302)
      end

      opts.on('--302-failure',
        'Consider HTTP 302 code an unsuccessful request') do
        options.http_statuses.delete(302)
      end

      opts.separator "\nRails environment"

      opts.on('--deployment','Use git fetch/reset instead of the safe/friendly checkout') do
        options.hard_reset = true
      end

      opts.on('--environment', '-e',
        'Change the rails environment we are profiling. Defaults to development') do |env|
        options.environment = env
      end

      opts.on('--no-caching',
        'Do not enable fragment caching (Rails.cache will still work)') do
        options.caching = false
      end

      opts.separator "\nMisc"

      opts.on('-h', 'Display this help') do
        # Do nothing, just don't error
      end

      opts.on('--run-migrations',
        'Run migrations on the branch and unmigrate at the end') do
        options[:run_migrations?] = true
      end

      opts.on('--cookie COOKIE', '-c') do |cookie|
        options.cookie = cookie
      end

      opts.on('--header HEADER', '-H') do |header|
        key, value = header.split(':', 2)
        options.headers[key.strip] = value.strip
      end

      opts.on('--input FILE', '-i') do |input|
        File.readlines(input).each do |resource|
          ARGV << resource.strip
        end
      end

      opts.on('--brief', '-b') do
        options.brief = true
      end

      opts.on('--verify-no-diff',
              'Check whether there is a diff between the responses of this and the reference branch') do
        options.verify_no_diff = true
      end

     opts.on('--diff') do
       options.diff = true
       options.brief = true
       options.verify_no_diff = true
       options.number_of_requests = 1
     end

     opts.on("--diff-option OPT") do |opt|
       options.diff_options << opt
     end

     opts.separator ''
     opts.separator <<EOF
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

  Just diff the output on your branch with master
     perf_check /user/45/posts --diff

  Diff a bunch of urls listed in a file (newline seperated)
    perf_check --diff --input FILE
EOF

      opts.separator ''
    end
  end
end
