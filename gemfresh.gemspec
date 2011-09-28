Gem::Specification.new do |s|
  s.name        = 'gemfresh'
  s.version     = '1.0'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Jon Williams']
  s.email       = ['jon@jonathannen.com']
  s.homepage    = 'https://github.com/jonathannen/gemfresh'
  s.summary     = 'Checks the freshness of your Gemfile.'
  s.description = 'Scans Gemfiles to check for obsolete and updateable gems.'

  s.files         = ['gemspec.rb', 'bin/gemspec']
  s.test_files    = []
  s.executables   = ['gemspec']
  s.require_paths = ['.']

  s.add_runtime_dependency 'bundler', '~> 1.0.18'
end