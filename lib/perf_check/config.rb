require 'optparse'

class PerfCheck
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

      opts.on('--quick', '-q',
              'Fire off 20 requests just on this branch (no comparison with master)') do
        options.reference = nil
      end

      opts.on('--no-caching', 'Do not enable fragment caching') do
        options.caching = false
      end

      opts.on('--run-migrations', 'Run migrations on the branch and unmigrate at the end') do
        options[:run_migrations?] = true
      end

      opts.on('--302-success', 'Consider HTTP 302 code a successful request') do
        options.http_statuses.push(302)
      end

      opts.on('--302-failure', 'Consider HTTP 302 code an unsuccessful request') do
        options.http_statuses.delete(302)
      end

      opts.separator "\nMisc"
      opts.on('--cookie COOKIE', '-c') do |cookie|
        options.cookie = cookie
      end

      opts.on('--header HEADER', '-H') do |header|
        key, value = header.split(':', 2)
        options.headers[key.strip] = value.strip
      end

      opts.on('--json', '-j') do
        options.json = true
      end

      opts.on('--input FILE', '-i') do |input|
        File.readlines(input).each do |resource|
          ARGV << resource.strip
        end
      end

      opts.on('--verify-responses',
              'Check whether there is a diff between the responses of this and the reference branch') do
        options.verify_responses = true
      end

      opts.on('--brief', '-b') do
        options.brief = true
      end

#      opts.on('--diff') do
#        options.diff = true
#        options.brief = true
#        options.verify_responses = true
#        options.number_of_requests = 1
#      end

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
     perf_check /user/45/posts --verify-responses

  Just diff the output on your branch with master
     perf_check /user/45/posts --diff

  Diff a bunch of urls listed in a file (newline seperated)
    perf_check --diff --input FILE
EOF

      opts.separator ''
    end
  end

  def self.diff_options
    @@diff_options ||=
      ['-U3', '--ignore-matching-lines=/mini-profiler-resources/includes.js']
  end
end
