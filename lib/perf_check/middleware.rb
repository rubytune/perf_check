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
      status, headers, body = app.call(env)

      headers['X-PerfCheck-Query-Count'] = query_count.to_s

      [status, headers, body]
    end
  end
end
