class PerfCheck
  class Middleware
    attr_reader :app
    attr_accessor :query_count

    def initialize(app)
      @app = app

      self.query_count = 0
      ActiveSupport::Notifications.subscribe('sql.active_record') do |_|
        self.query_count += 1
      end
    end

    def call(env)
      self.query_count = 0

      begin
        status, headers, body = app.call(env)
      rescue ::Exception => e
        trace_file = "#{Rails.root}/tmp/perf_check_traces" <<
                     "/trace-#{SecureRandom.hex(16)}.txt"
        FileUtils.mkdir_p(File.dirname(trace_file))

        File.open(trace_file, 'w') do |f|
          f.puts("#{e.class}: #{e.message}")
          f.write(e.backtrace.join("\n"))
        end
        status, headers, body = 500, {"X-PerfCheck-StackTrace" => trace_file}, ['']
      end

      headers['X-PerfCheck-Query-Count'] = query_count.to_s

      [status, headers, body]
    end
  end
end
