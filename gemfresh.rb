require 'net/http'
require 'rubygems'
require 'bundler'
require 'time'
require File.dirname(__FILE__) + '/support'

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
  # version = spec.version.to_s
  
  # Get a connection to the rubygem repository, reusing if we can
  remote = spec.source.remotes.first
  next if remote.nil?
  reader = sources[remote]
  reader = sources[remote] = RubyGemReader.new(remote) if reader.nil?
  
  # Get the RubyGems data
  # lookup = RubyGems.get("/api/v1/gems/#{name}.yaml")
  gemdata = reader.get("/api/v1/gems/#{name}.yaml")
  gemdata = YAML.load(gemdata)

  # Get the versions list as well
  versions = reader.get("/api/v1/versions/#{name}.yaml")
  versions = YAML.load(versions)
  
  # Store the result as a diff object
  diff = SpecDiff.new(dep, spec, gemdata, versions)
  results[diff.classify] << diff
  
  # Stats
  prereleases +=1 if diff.prerelease?
  count += 1
  print "."
  STDOUT.flush
end
puts " Done!"

# Let the user about prereleases
if prereleases > 0
  puts "\nYou have #{prereleases} prerelease gem#{prereleases == 1 ? '' : 's'}. Prereleases will be marked with a '*'."
end

# Output Gem Ages
puts "\nThe following Gems are:"
ages = results.values.flatten.group_by(&:build_age)
{:none => 'No build dates available', :month1 => 'less than a month old', :month6 => 'less than 6 months old', :year1 => 'less than a year old', :more => 'more than a year old'}.each_pair do |key, value|
  next if ages[key].nil?
  puts "-- #{value}:"
  puts ages[key].map(&:to_s).join(', ')
end

# Output Current Gems
if results[:current].empty?
  puts "\nYou don't have any current gems."
else
  puts "\nThe following gems at the most current version: "
  puts results[:current].map(&:to_s).join(', ')
end

# Output Updatable Gems
if results[:update].empty?
  puts "\nYou don't have any updatable gems."
else
  puts "\nThe following gems are locked to older versions, but your Gemfile allows for the current version: "
  results[:update].each do |diff| 
    puts "    #{diff}, with #{diff.dep.requirement} could allow #{diff.version_available}"
  end
  puts "Barring dependency issues, these gems could be updated to current using 'bundle update'."
end

# Output Obsolete Gems
if results[:obsolete].empty?
  puts "\nYou don't have any obsolete gems."
else
  puts "\nThe following gems are obsolete: "
  results[:obsolete].each do |diff|
    released = diff.version_build_date(diff.version_available)
    released = released.nil? ? '.' : ", #{released.strftime('%d %b %Y')}."

    suggest = diff.suggest
    suggest = suggest.nil? ? '' : "Also consider version #{suggest}."
    
    puts "    #{diff} is now at #{diff.version_available}#{released} #{suggest}"    
  end
end




























