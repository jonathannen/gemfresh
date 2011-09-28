Gem::Specification.new do |s|
  s.name        = 'gemfresh'
  s.version     = '1.0.1'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Jon Williams']
  s.email       = ['jon@jonathannen.com']
  s.homepage    = 'https://github.com/jonathannen/gemfresh'
  s.summary     = 'Checks the freshness of your Gemfile.'
  s.description = 'Scans Gemfiles to check for obsolete and updateable gems.'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['.']

  s.add_runtime_dependency 'bundler', '~> 1.0.18'
end