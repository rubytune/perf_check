# frozen_string_literal: true

class PerfCheck
  BANNER = "PERRRRF CHERRRK! Grab a ☕️ and don't touch your working tree " \
           "(we automate git)"
  BANNER_BORDER = '=' * BANNER.length

  def when_finished(&block)
    @when_finished_callbacks ||= []
    @when_finished_callbacks << block
  end

  def when_finished_callbacks
    @when_finished_callbacks || []
  end

  def before_start(&block)
    @before_start_callbacks ||= []
    @before_start_callbacks << block
  end

  def before_start_callbacks
    (@before_start_callbacks || []) + [
      proc { |perf_check|
        perf_check.logger.info(BANNER_BORDER)
        perf_check.logger.info(BANNER)
        perf_check.logger.info(BANNER_BORDER)
      }
    ]
  end

  def trigger_before_start_callbacks(test_case)
    before_start_callbacks.each { |f| f.call(self, test_case) }
  end

  def trigger_when_finished_callbacks(data={})
    data = data.merge(current_branch: git.detect_current_branch)
    results = OpenStruct.new(data)
    if test_cases.size == 1
      results.current_latency = test_cases.first.this_latency
      results.reference_latency = test_cases.first.reference_latency
    end
    when_finished_callbacks.each{ |f| f.call(self, results) }
  end
end
