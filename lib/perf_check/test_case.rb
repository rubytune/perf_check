# coding: utf-8

require 'diffy'

class PerfCheck
  class TestCase
    attr_reader :perf_check
    attr_accessor :resource
    attr_accessor :cookie, :this_response, :reference_response
    attr_accessor :this_profiles, :reference_profiles
    attr_accessor :http_status, :max_memory, :error_backtrace

    def initialize(perf_check, request_path)
      @perf_check = perf_check
      self.this_profiles = []
      self.reference_profiles = []
      self.resource = self.class.normalize_request_path(request_path)
    end

    def run(server, options)
      unless options.diff
        perf_check.logger.info("\t"+['request', 'latency', 'server rss', 'status', 'queries', 'profiler data'].map(&:underline).join("   "))
      end

      (options.number_of_requests + 2).times do |i|
        profile = issue_request(server, options)
        next if i < 2 # first 2 requests warm up the server/db and get tossed

        if options.verify_no_diff && i == 2
          response_for_comparison(profile.response_body)
        end

        unless options.diff
          row = sprintf("\t%2i:\t  %.1fms   %4dMB\t  %s\t   %s\t   %s",
                        i, profile.latency, profile.server_memory,
                        profile.response_code, profile.query_count, profile.profile_url)
          perf_check.logger.info(row)
          self.max_memory = profile.server_memory
        end

        context_profiles << profile

        self.http_status = '200'

        unless options.http_statuses.include?(profile.response_code)
          self.http_status = profile.response_code
          
          error = sprintf("\t  :\tFAILED! (HTTP %d)", profile.response_code)
          perf_check.logger.warn(error.red.bold)
          perf_check.logger.warn("\t   The server responded with an invalid http code")
          if profile.backtrace
            perf_check.logger.warn("Backtrace found:")
            backtrace = [profile.backtrace[0], *profile.backtrace.grep(/#{perf_check.app_root}/)]
            self.error_backtrace = ''
            backtrace.each do |line|
              perf_check.logger.warn("  #{line}")
              self.error_backtrace += "#{line}\n"
            end
          end
          break
        end
      end

      perf_check.logger.info '' unless options.diff # pretty!
    end

    def this_latency
      this_profiles.map(&:latency).inject(0.0, :+) / this_profiles.size
    end

    def reference_latency
      return nil if reference_profiles.empty?
      reference_profiles.map(&:latency).inject(0.0, :+) / reference_profiles.size
    end

    def this_query_count
      this_profiles.map(&:query_count).inject(0, :+) / this_profiles.size
    end

    def reference_query_count
      return nil if reference_profiles.empty?
      reference_profiles.map(&:query_count).inject(0, :+) / reference_profiles.size
    end

    def latency_difference
      this_latency - reference_latency
    end

    def speedup_factor
      reference_latency.to_f / this_latency.to_f
    end

    def response_diff
      diff = Diffy::Diff.new(reference_response, this_response,
                             include_diff_info: true,
                             diff: perf_check.options.diff_options)
      if diff.to_s(:text).lines.length < 3
        OpenStruct.new(:changed? => false)
      else
        FileUtils.mkdir_p("#{perf_check.app_root}/tmp/perf_check/diffs")
        file = `mktemp -u "#{perf_check.app_root}/tmp/perf_check/diffs/XXXXXXXXX"`.strip
        File.open("#{file}.diff", "w") do |f|
          f.write(diff.to_s(:text).lines[2..-1].join)
        end
        OpenStruct.new(:changed? => true, :file => "#{file}.diff")
      end
    end

    def eql?(test)
      resource == test.resource
    end

    def hash
      resource.hash
    end

    def issue_request(server, options)
      server.profile do |http|
        http.get(resource, request_headers)
      end
    end

    def request_headers
      headers = {'Cookie' => "#{cookie}".strip}
      headers['Accept'] = 'text/html,application/xhtml+xml,application/xml'
      headers.merge!(perf_check.options.headers)
    end

    def switch_to_reference_context
      @context = :reference
    end

    def self.normalize_request_path(request_path)
      return unless request_path

      request_path.start_with?('/') ? request_path : '/' + request_path
    end

    private

    def context_profiles
      (@context == :reference) ? reference_profiles : this_profiles
    end

    def response_for_comparison(response_body)
      if @context == :reference
        self.reference_response = response_body
      else
        self.this_response = response_body
      end
    end
  end
end
