class PerfCheck
  class Railtie < Rails::Railtie

    config.before_initialize do

      if defined?(Rack::MiniProfiler) && ENV['PERF_CHECK']
        # Integrate with rack-mini-profiler
        tmp = "#{Rails.root}/tmp/perf_check/miniprofiler"
        FileUtils.mkdir_p(tmp)

        Rack::MiniProfiler.config.storage_instance =
          Rack::MiniProfiler::FileStore.new(:path => tmp)
      end

      if ENV['PERF_CHECK']
        # Force cacheing .... :\
        config = Rails::Application::Configuration
        config.send(:define_method, :cache_classes){ true }

        fragment_caching = !ENV['PERF_CHECK_NOCACHING']
        config = ActiveSupport::Configurable::Configuration
        config.send(:define_method, :perform_caching){ fragment_caching }
      end

      if ENV['PERF_CHECK'] && ENV['PERF_CHECK_VERIFICATION']
        PerfCheck::Server.seed_random!
      end
    end
  end
end
