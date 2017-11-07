
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
      @pid ||= (File.read(pid_file).to_i if File.exists?(pid_file))
    end

    def pid_file
      @pid_file ||= File.join(perf_check.app_root, "/tmp/pids/server.pid")
    end

    def remove_pid_file
      if pid_file
        File.unlink(pid_file) if File.exist?(pid_file)
      end
      @pid_file = nil
      @pid = nil
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
      http = Net::HTTP.new(host, port).tap{ |ht| ht.read_timeout = 1000 }
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
    rescue Errno::ECONNREFUSED
      raise Exception.new("Couldn't connect to the rails server -- it either failed to boot or crashed")
    end

    def exit
      if pid && is_live_pid?(pid)
        kill_process(pid) do
          remove_pid_file
        end
      else
        perf_check.logger.warn "Server PID=#{pid} is no longer running; cleaning up."
        remove_pid_file
      end
      if pid
        abort "Could not kill server PID=#{pid}!"
      end
      @running = false
    end

    def is_live_pid?(pid)
      begin
        Process.getpgid(pid)
        true
      rescue Errno::ESRCH
        false
      end
    end

    # kill a process, first with QUIT, then with KILL

    def kill_process(pid)
      %w( QUIT KILL ).each do |signal|
        kill_pid(signal, pid)
        if wait_pid(pid)
          yield if block_given?
          break
        end
      end
    end

    def kill_pid(signal, pid)
      Process.kill(signal, pid) rescue nil
    end

    def wait_pid(pid)
      Process.waitpid(pid) rescue nil
    end

    # start and restart accepts a hash of envar names and values

    def start(envars = nil)
      set_envars(envars)
      app_root = Shellwords.shellescape(perf_check.app_root)
      system("( cd #{app_root} && bundle exec rails server -b 127.0.0.1 -d -p 3031) | 2>&1 tee -a perf_check_debug.log")
      sleep(1.5)
      @running = true
    end

    def restart(envars = nil)
      perf_check.logger.info("#{running? ? 're-' : ''}starting rails...")
      exit if running?
      start(envars)
    end

    def set_envars(envars = nil)
      (envars || {}).each_pair do |var, val|
        ENV[var] = val
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
  end
end
