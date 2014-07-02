
require 'net/http'
require 'benchmark'
require 'ostruct'
require 'fileutils'

class PerfCheck
  class Server
    def self.authorization(&block)
      define_method(:login, &block)
    end

    def self.authorization_action(method, login_route, &block)
      Rails.application.reload_routes!
      p = Rails.application.routes.recognize_path(login_route, :method => method)
      controller = "#{p[:controller]}_controller".classify.constantize
      action = p[:action]

      controller.send(:define_method, :get_perf_check_session, &block)
      controller.send(:define_method, action) do
        get_perf_check_session(params[:login], params[:route])
        render :nothing => true
      end
      controller.send(:skip_before_filter, :verify_authenticity_token)

      authorization do |login, route|
        http = Net::HTTP.new(host, port)
        if method == :post
          response = http.post(login_route, "login=#{login}")
        elsif method == :get
          response = http.get(login_route+"?login=#{login}")
        end

        response['Set-Cookie']
      end
    end

    def self.sign_cookie_data(key, data, opts={})
      opts[:serializer] ||= Marshal
      secret = Rails.application.config.secret_token

      marshal = ActiveSupport::MessageVerifier.new(secret,
                                                   :serializer => opts[:serializer])
      marshal_value = marshal.generate(data)

      "#{key}=#{marshal_value}"
    end

    def initialize
      at_exit do
        exit
      end
    end

    def login(login, route)
      ''
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

      latency = 1000 * Benchmark.measure do
        http.start
        response = yield(http)
        http.finish
      end.real

      case response.code
      when '200'
        Profile.new.tap do |result|
          result.latency = latency
          result.profile_url = latest_profiler_url
          result.response_body = response.body
        end
      else
        raise Server::ApplicationError.new(response) unless response.code == '200'
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
      system('rails server -b 127.0.0.1 -d -p 3031 >/dev/null')
      sleep(1.5)

      @running = true
    end

    def restart
      if !@running
        $stderr.print "starting rails..."
        start
      else
        $stderr.print "re-starting rails..."
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

    class ApplicationError < Exception
      def initialize(resp)
        @response = resp
      end
      def code
        @response.code
      end
      def body
        @response.body
      end
    end
    class Profile < OpenStruct; end
  end
end
