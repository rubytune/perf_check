require 'securerandom'

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
      rescue => error
        status, headers, body = 500, { "X-PerfCheck-StackTrace" => stacktrace_for(error) }, ['']
      end
      headers['X-PerfCheck-Query-Count'] = query_count.to_s
      [status, headers, body]
    end

    # These files are used by the perf_check daemon app
    def stacktrace_for(e)
      trace_file = "#{Rails.root}/tmp/perf_check_traces" <<
                   "/trace-#{SecureRandom.hex(16)}.txt"
      FileUtils.mkdir_p(File.dirname(trace_file))

      File.open(trace_file, 'w') do |f|
        f.puts("#{e.class}: #{e.message}")
        f.write(e.backtrace.join("\n"))
      end
      trace_file
    end


  end
end
