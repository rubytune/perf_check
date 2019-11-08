# frozen_string_literal: true

require_relative 'lib/perf_check/version'

Gem::Specification.new do |s|
  s.name = 'perf_check'
  s.version = PerfCheck::VERSION
  s.date = '2019-07-02'
  s.summary = 'PERF CHECKKK!'
  s.authors = %w[rubytune]
  s.homepage = 'https://github.com/rubytune/perf_check'
  s.license = 'MIT'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'pry'
  s.add_runtime_dependency 'colorize'
  s.add_runtime_dependency 'diffy'
  s.add_runtime_dependency 'rake'

  s.files = \
    Dir.glob('bin/*') +
    Dir.glob('lib/**/*') +
    %w[
      README.md
    ]

  s.require_paths = %w[lib]
  s.executables << 'perf_check'
end
