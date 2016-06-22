Gem::Specification.new do |s|
  s.name = 'perf_check'
  s.version = '0.7.4'
  s.date = '2016-03-30'
  s.summary = 'PERF CHECKKK!'
  s.authors = ['rubytune']
  s.homepage = 'https://github.com/rubytune/perf_check'
  s.license = 'MIT'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'pry'
  s.add_runtime_dependency 'colorize', '= 0.7.3'
  s.add_runtime_dependency 'diffy', '= 3.0.5'

  s.files = ['lib/perf_check.rb',
             'lib/perf_check/callbacks.rb',
             'lib/perf_check/config.rb',
             'lib/perf_check/git.rb',
             'lib/perf_check/middleware.rb',
             'lib/perf_check/output.rb',
             'lib/perf_check/railtie.rb',
             'lib/perf_check/server.rb',
             'lib/perf_check/test_case.rb']

  s.executables << 'perf_check'
end
