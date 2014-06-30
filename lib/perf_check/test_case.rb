# coding: utf-8

class PerfCheck
  class TestCase
    attr_accessor :resource, :controller, :action
    attr_accessor :latencies, :cookie
    attr_accessor :this_latencies, :reference_latencies

    def initialize(route)
      params = Rails.application.routes.recognize_path(route)

      self.this_latencies = []
      self.reference_latencies = []
      self.latencies = this_latencies

      self.controller = params[:controller].split('/')[-1]
      self.action = params[:action]
      self.resource = route
    end

    def run(server, count)
      (count+1).times do |i|
        errors = 0
        begin
          profile = server.profile do |http|
            http.get(resource, {'Cookie' => cookie})
          end
        rescue Server::ApplicationError => e
          File.open("public/perf_check_failed_request.html", 'w') do |error_dump|
            error_dump.write(e.body)
          end
          printf("\tRequest %2i: —— FAILURE (HTTP %s): %s\n",
                 i, e.code, '/perf_check_failed_request.html')
          exit(1)
        end

        # Disregard initial request, since in dev. mode it includes
        # all the autoload overhead (?)
        next if i.zero?

        printf("\tRequest %2i: %.1fms\t%4dMB\t%s\n",
               i, profile.latency, server.mem, profile.profile_url)

        self.latencies << profile.latency
      end
      puts
    end

    def this_latency
      this_latencies.inject(0.0, :+) / this_latencies.size
    end

    def reference_latency
      reference_latencies.inject(0.0, :+) / reference_latencies.size
    end

    def latency_difference
      this_latency - reference_latency
    end

    def latency_factor
      reference_latency / this_latency
    end

    def eql?(test)
      resource == test.resource
    end

    def hash
      resource.hash
    end
  end
end
