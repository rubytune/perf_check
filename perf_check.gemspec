lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'perf_check/version'

Gem::Specification.new do |s|
  s.name = 'perf_check'
  s.version = PerfCheck::VERSION
  s.date = '2017-11-13'
  s.summary = 'PERF CHECKKK!'
  s.authors = ['rubytune']
  s.homepage = 'https://github.com/rubytune/perf_check'
  s.license = 'MIT'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'fuubar'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'pry'
  s.add_runtime_dependency 'colorize'
  s.add_runtime_dependency 'diffy'
  s.add_runtime_dependency 'rake'
  s.add_runtime_dependency 'fuubar'
  s.add_runtime_dependency 'pry-byebug'

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
