# coding: utf-8
class PerfCheck
  def self.when_finished(&block)
    @when_finished_callbacks ||= []
    @when_finished_callbacks << block
  end

  def self.when_finished_callbacks
    @when_finished_callbacks || []
  end

  def self.before_start(&block)
    @before_start_callbacks ||= []
    @before_start_callbacks << block
  end

  def self.before_start_callbacks
    (@before_start_callbacks || []) + [
      proc {
        logger.info("=" * 77)
        logger.info("PERRRRF CHERRRK! Grab a ☕️  and don't touch your working tree (we automate git)")
        logger.info("=" * 77)
      }
    ]
  end


  def trigger_before_start_callbacks(test_case)
    PerfCheck.before_start_callbacks.each{ |f| f.call(self, test_case) }
  end

  def trigger_when_finished_callbacks(data={})
    data = data.merge(:current_branch => PerfCheck::Git.current_branch)
    results = OpenStruct.new(data)
    results[:ARGV] = ORIGINAL_ARGV
    if test_cases.size == 1
      results.current_latency = test_cases.first.this_latency
      results.reference_latency = test_cases.first.reference_latency
    end
    PerfCheck.when_finished_callbacks.each{ |f| f.call(results) }
  end
end
