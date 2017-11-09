require "optparse"
require "shellwords"

require_relative 'version'

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

      options.branch_envs = {}
      options.reference_envs = {}

      opts.separator "\nBenchmark options:"
      opts.on('--requests N', '-n',
              'Use N requests in benchmark, defaults to 20') do |n|
        options.number_of_requests = n.to_i
      end

      opts.on('--reference COMMIT', '-r',
              'Benchmark against COMMIT instead of master') do |commit|
        options.reference = commit
      end

      opts.on('--quick', '-q',
              '20 requests just on this branch (no comparison with master)') do
        options.reference = nil
      end

      opts.on('--no-caching', 'Do not enable fragment caching (Rails.cache will still work)') do
        options.caching = false
      end

      opts.on('--run-migrations', '-M', 'Run migrations on the branch and unmigrate at the end') do
        options[:run_migrations?] = true
      end

      opts.on('--compare-paths', 'Compare two paths against each other on the same branch') do
        options[:compare_paths?] = true
      end

      opts.on('--branch-env VAR=VALUE', '-e', 'Set a branch-test environment variable') do |var_value|
        var, value = var_value.split('=').map(&:strip)
        options.branch_envs[var] = value
      end

      opts.on('--reference-env VAR=VALUE', '-E', 'Set a reference-test environment variable') do |var_value|
        var, value = var_value.split('=').map(&:strip)
        options.reference_envs[var] = value
      end

      opts.on('--302-success', 'Consider HTTP 302 code a successful request') do
        options.http_statuses.push(302)
      end

      opts.on('--302-failure', 'Consider HTTP 302 code an unsuccessful request') do
        options.http_statuses.delete(302)
      end

      opts.separator "\nMisc"
      opts.on('-h', 'Display this help') do
        # Do nothing, just don't error
      end

      opts.on('--deployment','Use git fetch/reset instead of the safe/friendly checkout') do
        options.hard_reset = true
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

     opts.on("--version") do
       $stderr.puts "Perf-Check version #{PerfCheck::VERSION}"
       exit
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

  Set/clear an envar for the comparison:
    perf_check -e QUERY_CACHE_ENABLED=true -E QUERY_CACHE_ENABLED=false /1234/project/home
EOF

      opts.separator ''
    end
  end
end
