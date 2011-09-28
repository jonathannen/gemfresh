require 'net/http'
require 'rubygems'
require 'bundler'

# Handle ARGV
if ARGV.include?('--help') 
  puts <<-HELP
  Usage:
    gemfresh [GEMFILE] [LOCKFILE]
    
  Both GEMFILE and LOCKFILE will default to "Gemfile" and "Gemfile.lock" in 
  your current directory. Generally you'll simply invoke gemfresh from your 
  Rails (or similar) project directory.
    
  Gemfresh will list three categories of gems. "Current" gems are up-to-date.
  "Obsolete" gems 
  
  "Updateable" gems that have a 'fuzzy' gemspec - e.g. '~> 2.2.0' is a fuzzy
  match for 2.2.1, 2.2.2, etc. Running bundle update will attempt to update
  your gems. If something is listed at updateable, you have an older version
  - e.g. "2.2.1", when the current is "2.2.2".

  Just because a gem is updateable or obsolete, doesn't mean it can be 
  updated. There might be dependencies that limit you to specific versions.

  Check the bundler documentation (http://gembundler.com/) for more 
  information on Gemfiles.
  HELP
  exit
end

# Check for gemfile and lockfiles
gemfile = ARGV[0] || './Gemfile'
lockfile = ARGV[1] || './Gemfile.lock'
unless File.exists?(gemfile)
  puts "Couldn't find #{gemfile}.\nRun gemfresh with --help if you need more information."
  exit
end
unless File.exists?(lockfile)
  puts "Couldn't find #{lockfile}.\nRun gemfresh with --help if you need more information."
  exit
end

# Front for RubyGems
class RubyGemReader < Struct.new('RubyGemReader', :uri)
  def get(path, data={}, content_type='application/x-www-form-urlencoded')
    request = Net::HTTP::Get.new(path)
    request.add_field 'Connection', 'keep-alive'
    request.add_field 'Keep-Alive', '30'
    request.add_field 'User-Agent', 'github.com/jonathannen/gemfresh'
    response = connection.request request
    response.body  
  end
  private
  # A persistent connection
  def connection(host = Gem.host)
    return @connection unless @connection.nil?
    @connection = Net::HTTP.new self.uri.host, self.uri.port
    @connection.start    
    @connection
  end
end

# Start in earnets
puts "Checking the freshness of your Gemfile.\n"

# Get the data from bundler
Bundler.settings[:frozen] = true
bundle = Bundler::Dsl.evaluate('./Gemfile', './Gemfile.lock', {})

# Set up the top level values
deps = bundle.dependencies
specs = bundle.resolve
sources = {}
results = { :current => [], :update => [], :obsolete => [] }
count = 0
prereleases = 0

# Map dependencies to their specs, then select RubyGem sources
dep_specs = deps.map { |dep| [dep, specs.find { |spec| spec.name == dep.name }] }
dep_specs = dep_specs.select { |dep, spec| !spec.nil? && (spec.source.class == Bundler::Source::Rubygems) }

# Do we have any deps?
if deps.empty?
  puts "No top-level RubyGem dependencies found in your Gemfile.\nRun gemfresh with --help if you need more information."
  exit
end

# Iterate through the deps, checking the spec against the latest version
print "Hitting up your RubyGems sources: "
dep_specs.each do |dep, spec|
  name = dep.name
  version = spec.version.to_s
  
  # Get a connection to the rubygem repository, reusing if we can
  remote = spec.source.remotes.first
  next if remote.nil?
  reader = sources[remote]
  reader = sources[remote] = RubyGemReader.new(remote) if reader.nil?
  
  # Get the RubyGems data
  # lookup = RubyGems.get("/api/v1/gems/#{name}.yaml")
  lookup = reader.get("/api/v1/gems/#{name}.yaml")
  lookup = YAML.load(lookup)
  current = lookup["version"].to_s
  
  # Exact match or directly updatable? If so, we can move on
  prerelease = false
  match = case
  when (version == current) then :current
  when (dep.match?(dep.name, current)) then :update
  else nil
  end
  
  # Not exact or updatable - we need to check if you're on a pre-release version
  if match.nil?
    match = :obsolete
    versions = reader.get("/api/v1/versions/#{name}.yaml")
    versions = YAML.load(versions).select { |v| v['prerelease']}.map { |v| v['number'] }
    prerelease = versions.include?(version)
    # If it's a prerelease determine what kind
    if prerelease
      prereleases += 1
      current = versions.first # Big assumption
      match = case
      when (version == current) then :current
      when (dep.match?(dep.name, current)) then :update
      else :obsolete
      end
    end
  end
  
  # Got our result
  results[match] << [dep, spec, current, prerelease]  
  count += 1
  print "."
  STDOUT.flush
end
puts " Done!"

# Warn the user about prereleases
if prereleases > 0
  puts "\nYou have #{prereleases} prerelease gem#{prereleases == 1 ? '' : 's'}. Prereleases will be marked with a '*'."
end

# Output Current Gems
if results[:current].empty?
  puts "\nYou don't have any current gems."
else
  puts "\nThe following gems are current: "
  puts results[:current].map { |dep, spec, current, prerelease| "#{spec}#{prerelease ? '*' : ''}" }.join(', ')
end

# Output Updatable Gems
if results[:update].empty?
  puts "\nYou don't have any updatable gems."
else
  puts "\nThe following gems are locked to older versions, but the spec allows for a later version: "
  results[:update].each do |dep, spec, current, prerelease| 
    pre = prerelease ? '*' : ''
    puts "    #{spec}#{pre}, with #{dep.requirement} could allow #{current}"
  end
end

# Output Obsolete Gems
if results[:obsolete].empty?
  puts "\nYou don't have any obsolete gems."
else
  puts "\nThe following gems are obsolete: "
  results[:obsolete].each do |dep, spec, current, prerelease|
    pre = prerelease ? '*' : ''
    puts "    #{spec}#{pre} is outdated - now at #{current}"
  end
end