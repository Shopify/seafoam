require_relative 'lib/seafoam/version'

Gem::Specification.new do |spec|
  spec.name     = 'seafoam'
  spec.version  = Seafoam::VERSION
  spec.summary  = 'A tool for working with compiler graphs'
  spec.authors  = ['Chris Seaton']
  spec.bindir   = 'bin'

  spec.add_development_dependency 'benchmark-ips', '~> 2.7.2'
  spec.add_development_dependency 'rspec', '~> 3.8.0'
  spec.add_development_dependency 'rubocop', '~> 0.74.0'
end
