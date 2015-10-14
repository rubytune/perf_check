class PerfCheck
  class Middleware
    attr_reader :app

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = app.call(env)
      [status, headers, body]
    end
  end
end
