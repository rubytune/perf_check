
require 'net/http'
require 'benchmark'
require 'ostruct'
require 'fileutils'

class PerfCheck
  class Server
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

    def initialize
      at_exit do
        exit rescue nil
      end
    end

    def pid
      pidfile = 'tmp/pids/server.pid'
      File.read(pidfile).to_i if File.exists?(pidfile)
    end

    def mem
      mem = `ps -o rss= -p #{pid}`.strip.to_f / 1024
    end

    def prepare_to_profile
      FileUtils.mkdir_p('tmp/perf_check/miniprofiler')
      Dir["tmp/perf_check/miniprofiler/*"].each{|x| FileUtils.rm(x) }
    end

    def latest_profiler_url
      mp_timer = Dir["tmp/perf_check/miniprofiler/mp_timers_*"].first
      if "#{mp_timer}" =~ /mp_timers_(\w+)/
        mp_link = "/mini-profiler-resources/results?id=#{$1}"
        FileUtils.mkdir_p('tmp/miniprofiler')
        FileUtils.mv(mp_timer, mp_timer.sub(/^tmp\/perf_check\//, 'tmp/'))
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

      Profile.new.tap do |result|
        result.latency = latency
        result.query_count = query_count
        result.profile_url = latest_profiler_url
        result.response_body = response.body
        result.response_code = response.code.to_i
      end
    end

    def exit
      p = pid
      if p
        Process.kill('QUIT', pid)
        sleep(1.5)
      end
    end

    def start
      ENV['PERF_CHECK'] = '1'
      if PerfCheck.config.verify_responses
        ENV['PERF_CHECK_VERIFICATION'] = '1'
      end
      unless PerfCheck.config.caching
        ENV['PERF_CHECK_NOCACHING'] = '1'
      end

      system('rails server -b 127.0.0.1 -d -p 3031 >/dev/null')
      sleep(1.5)

      @running = true
    end

    def restart
      if !@running
        logger.info("starting rails...")
        start
      else
        logger.info("re-starting rails...")
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

    class Profile < OpenStruct; end
  end
end
