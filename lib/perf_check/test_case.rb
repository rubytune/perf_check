# coding: utf-8

class PerfCheck
  class TestCase
    attr_accessor :resource, :controller, :action, :format
    attr_accessor :latencies, :cookie
    attr_accessor :this_latencies, :reference_latencies

    def initialize(route)
      params = Rails.application.routes.recognize_path(route)

      self.this_latencies = []
      self.reference_latencies = []
      self.latencies = this_latencies

      self.controller = params[:controller].split('/')[-1]
      self.action = params[:action]
      self.format = params[:format]
      self.resource = route
    end

    def run(server, options)
      print("\t"+'request #'.underline)
      print("  "+'latency'.underline)
      print("   "+'server rss'.underline)
      puts("   "+'profiler data'.underline)

      headers = {'Cookie' => "#{cookie}"}
      unless self.format
        headers['Accept'] = 'text/html,application/xhtml+xml,application/xml'
      end
      options.number_of_requests.times do |i|
        profile = server.profile do |http|
          http.get(resource, headers)
        end

        unless options.http_statuses.include? profile.response_code
          File.open("public/perf_check_failed_request.html", 'w') do |error_dump|
            error_dump.write(profile.response_body)
          end
          error = sprintf("\t%2i:\tFAILED! (HTTP %d)", i, profile.response_code)
          puts(error.red.bold)
          puts("\t   The server responded with a non-2xx status for this request.")
          print("\t   The response has been written to public")
          puts("/perf_check_failed_request.html".blue)
          exit(1)
        end

        printf("\t%2i:\t   %.1fms   %4dMB\t  %s\n",
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
