
require 'logger'

class PerfCheck
  def self.logger
    @logger ||= Logger.new(STDERR).tap do |logger|
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime}] #{sprintf('%5s', severity)} --: #{msg}\n"
      end
    end
  end

  def logger; self.class.logger; end
end

class Object
  def self.logger; PerfCheck.logger; end
  def logger; PerfCheck.logger; end
end
