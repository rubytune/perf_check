class PerfCheck
  class Railtie < Rails::Railtie
    config.before_initialize do |app|

      if defined?(Rack::MiniProfiler)
        # Integrate with rack-mini-profiler
        tmp = "#{Rails.root}/tmp/perf_check/miniprofiler"
        FileUtils.mkdir_p(tmp)

        Rack::MiniProfiler.config.storage_instance =
          Rack::MiniProfiler::FileStore.new(:path => tmp)
      end

      # Force caching & production-like settings
      config = Rails::Application::Configuration
      config.send(:define_method, :cache_classes){ true }
      config.send(:define_method, :eager_load){true}

      fragment_caching = !ENV['PERF_CHECK_NOCACHING']
      config = ActiveSupport::Configurable::Configuration
      config.send(:define_method, :perform_caching){ fragment_caching }

      if ENV['PERF_CHECK_VERIFICATION']
        PerfCheck::Server.seed_random!
      end

      require 'perf_check/middleware'
      app.middleware.insert_before 0, PerfCheck::Middleware
    end
  end
end
