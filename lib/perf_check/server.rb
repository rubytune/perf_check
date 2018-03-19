
require 'net/http'
require 'benchmark'
require 'ostruct'
require 'fileutils'
require 'shellwords'

class PerfCheck
  class Server
    attr_reader :perf_check

    def self.seed_random!
      # Seed random
      srand(1)

      # SecureRandom cannot be seeded, so we have to monkey patch it instead :\
      def SecureRandom.hex(n=16)
        '4' * n
      end

      def SecureRandom.random_bytes(n=16)
        '4' * n
      end

      def SecureRandom.random_number(n=0)
        n > 4 ? 4 : n
      end

      def SecureRandom.urlsafe_base64(n=16, padding=false)
        '4' * (4*n / 3)
      end

      def SecureRandom.uuid
        "00000000-0000-0000-0000-000000000004"
      end
    end

    def initialize(perf_check)
      @perf_check = perf_check
    end

    def pid
      File.read(pidfile).to_i if File.exists?(pidfile)
    end

    def mem
      `ps -o rss= -p #{pid}`.strip.to_f / 1024
    end

    def prepare_to_profile
      app_root = perf_check.app_root
      FileUtils.mkdir_p("#{app_root}/tmp/perf_check/miniprofiler")
      Dir["#{app_root}/tmp/perf_check/miniprofiler/*"].each{|x| FileUtils.rm(x) }
    end

    def latest_profiler_url
      app_root = perf_check.app_root
      mp_timer = Dir["#{app_root}/tmp/perf_check/miniprofiler/mp_timers_*"].first
      if "#{mp_timer}" =~ /mp_timers_(\w+)/
        mp_link = "/mini-profiler-resources/results?id=#{$1}"
        FileUtils.mkdir_p("#{app_root}/tmp/miniprofiler")
        FileUtils.mv(mp_timer, mp_timer.sub(/^#{app_root}\/tmp\/perf_check\//, "#{app_root}/tmp/"))
      end
      mp_link
    end

    def profile
      http = Net::HTTP.new(host, port).tap{ |http| http.read_timeout = 1000 }
      response = nil
      prepare_to_profile

      http.start
      response = yield(http)
      http.finish

      latency = 1000 * response['X-Runtime'].to_f
      query_count = response['X-PerfCheck-Query-Count'].to_i
      backtrace_file = response['X-PerfCheck-StackTrace']

      Profile.new.tap do |result|
        result.latency = latency
        result.query_count = query_count
        result.profile_url = latest_profiler_url
        result.response_body = response.body
        result.response_code = response.code.to_i
        result.server_memory = mem
        if backtrace_file
          result.backtrace = File.read(backtrace_file).lines.map(&:chomp)
        end
      end
    rescue Errno::ECONNREFUSED => e
      raise Exception.new("Couldn't connect to the rails server -- it either failed to boot or crashed")
    end

    def exit
      if pid
        Process.kill('KILL', pid)
        sleep(1.5)
        File.delete(pidfile) if File.exist?(pidfile)
      end
    end

    def start
      perf_check_args = { 'PERF_CHECK': '1', 'DISABLE_SPRING': '1' }
      if perf_check.options.verify_no_diff
        perf_check_args['PERF_CHECK_VERIFICATION'] = '1'
      end
      unless perf_check.options.caching
        perf_check_args['PERF_CHECK_NOCACHING'] = '1'
      end

      app_root = Shellwords.shellescape(perf_check.app_root)
      Bundler.with_original_env do
        Dir.chdir app_root do
          pid = Process.spawn(
            perf_check_args,
            "bundle exec rails server -b #{host} -d -p #{port}",
            [:out] => '/dev/null'
          )
          Process.wait pid
        end
      end
      sleep(1.5)

      @running = true
    end

    def restart
      if !running?
        perf_check.logger.info("starting rails...")
        start
      else
        perf_check.logger.info("re-starting rails...")
        exit
        start
      end
    end

    def host
      "127.0.0.1"
    end

    def port
      3031
    end

    def running?
      @running
    end

    class Profile < OpenStruct; end

    private

    def pidfile
      @pidfile ||= "#{perf_check.app_root}/tmp/pids/server.pid"
    end
  end
end
