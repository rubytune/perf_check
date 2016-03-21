# coding: utf-8

require 'diffy'

class PerfCheck
  class TestCase
    attr_accessor :resource, :did_error
    attr_accessor :cookie, :this_response, :reference_response
    attr_accessor :this_profiles, :reference_profiles

    def initialize(route)
      self.this_profiles = []
      self.reference_profiles = []
      self.resource = route
    end

    def switch_to_reference_context
      @context = :reference
    end

    def run(server, options)
      unless options.diff
        PerfCheck.logger.info("\t"+['request', 'latency', 'server rss', 'status', 'queries', 'profiler data'].map(&:underline).join("   "))
      end

      profiles = (@context == :reference) ? reference_profiles : this_profiles

      headers = {'Cookie' => "#{cookie}".strip}
      headers['Accept'] = 'text/html,application/xhtml+xml,application/xml'
      headers.merge!(PerfCheck.config.headers)

      (options.number_of_requests + 1).times do |i|
        profile = server.profile do |http|
          http.get(resource, headers)
        end

        # Be as verbose as possible with errors
        unless options.http_statuses.include? profile.response_code
          self.did_error = true
          error = sprintf("\t%2i:\tFAILED! (HTTP %d) ", i, profile.response_code)
          File.open("tmp/perf_check/failed_request.html", 'w') do |error_dump|
            if $!
              error_dump.write "#{$!.class}: #{$!.message}\n"
              error_dump.write $!.backtrace.map{|x| "\t#{x}"}.join("\n")
            end
            error_dump.write(error)
            error_dump.write(profile.response_body)
          end
          PerfCheck.logger.fatal(error.red.bold)
          PerfCheck.logger.fatal("\t   The server responded with a non-2xx status for this request.")
          PerfCheck.logger.fatal("\t   The response has been written to tmp/perf_check/failed_request.html")
        end

        # store the response bodies in the test case if we want the diff or error
        if did_error or (options.verify_responses && i == 1)
          if @context == :reference
            self.reference_response = profile.response_body
          else
            self.this_response = profile.response_body
          end
        end
                
        # throw away the first request, don't include in benchmarks
        next if i.zero? 

        profile.server_memory = server.mem

        unless options.diff 
          row = sprintf("\t%2i:\t  %.1fms   %4dMB\t  %s\t   %s\t   %s",
                        i, profile.latency, profile.server_memory,
                        profile.response_code, profile.query_count, profile.profile_url)
          PerfCheck.logger.info(row)
        end

        profiles << profile
        break if did_error# && options.fail_fast? # don't run more requests
      end

      PerfCheck.logger.info '' unless options.diff # pretty!
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

    def latency_factor
      reference_latency / this_latency
    end
  
    def response_diff
      diff = Diffy::Diff.new(this_response, reference_response,
                             :diff => PerfCheck.diff_options)
      if diff.to_s.empty?
        OpenStruct.new(:changed? => false)
      else
        FileUtils.mkdir_p("#{Rails.root}/tmp/perf_check/diffs")
        file = `mktemp -u "#{Rails.root}/tmp/perf_check/diffs/XXXXXXXXXX"`.strip
        [:text, :html].each do |format|
          ext = {:text => 'diff', :html => 'html'}[format]
          File.open("#{file}.#{ext}", 'w'){ |f| f.write(diff.to_s(format)) }
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
  end
end
