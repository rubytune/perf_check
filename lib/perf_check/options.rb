require 'optparse'

class PerfCheck
  def self.config
    @config ||= OpenStruct.new(
      number_of_requests: 10,
      reference: 'master',
      cookie: nil,
      http_statuses: [200],
      verify_responses: false,
      caching: true,
      json: false
     )
  end

  def config
    PerfCheck.config
  end

  alias :options :config

  Options = OptionParser.new do |opts|
    opts.banner = "Usage: perf_check [options] [route ...]"

    opts.separator "\nBenchmark options:"
    opts.on('--requests N', '-n',
            'Use N requests in benchmark, defaults to 10') do |n|
      config.number_of_requests = n.to_i
    end

    opts.on('--reference COMMIT', '-r',
            'Benchmark against COMMIT instead of master') do |commit|
      config.reference = commit
    end

    opts.on('--quick', '-q',
            'Fire off 5 requests just on this branch, no comparison with master') do
      config.number_of_requests = 5
      config.reference = nil
    end

    opts.on('--no-caching', 'Do not enable fragment caching') do
      config.caching = false
    end

    opts.on('--fail-fast', '-f', 'Bail immediately on non-200 HTTP response') do
      config[:fail_fast?] = true
    end

    opts.on('--302-success', 'Consider HTTP 302 code a successful request') do
      config.http_statuses.push(302)
    end

    opts.on('--302-failure', 'Consider HTTP 302 code an unsuccessful request') do
      config.http_statuses.delete(302)
    end

    opts.separator "\nMisc"
    opts.on('--cookie COOKIE', '-c') do |cookie|
      config.cookie = cookie
    end

    opts.on('--json', '-j') do
      config.json = true
    end

    opts.on('--input FILE', '-i') do |input|
      File.readlines(input).each do |resource|
        ARGV << resource.strip
      end
    end

    opts.on('--verify-responses',
            'Check whether there is a diff between the responses of this and the reference branch') do
      config.verify_responses = true
    end

    opts.on('--brief', '-b') do
      config.brief = true
    end

    opts.on('--diff') do
      config.diff = true
      config.brief = true
      config.verify_responses = true
      config.number_of_requests = 1
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
     perf_check /user/45/posts --verify-responses

  Just diff the output on your branch with master
     perf_check /user/45/posts --diff

  Diff a bunch of urls listed in a file (newline seperated)
    perf_check --diff --input FILE
EOF

    opts.separator ''
  end
end
