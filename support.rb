require 'net/http'

# Front for RubyGems
class SourceUnavailableError < StandardError; end
class RubyGemReader
  attr_reader :uri
  
  def initialize(uri)
    @connection = nil
    @uri = uri.kind_of?(URI::Generic) ? uri : URI(uri.to_s)
  end
  
  # May raise SourceUnavailableError if the source can't be accessed
  def get(path, data={}, content_type='application/x-www-form-urlencoded')
    begin
      request = Net::HTTP::Get.new(path)
      request.add_field 'Connection', 'keep-alive'
      request.add_field 'Keep-Alive', '30'
      request.add_field 'User-Agent', 'github.com/jonathannen/gemfresh'
      response = connection.request request
      response.body  
    rescue StandardError => se
      # For now we assume this is an unavailable repo
      raise SourceUnavailableError.new(se.message)
    end
  end
  
  private
  # A persistent connection
  def connection
    return @connection unless @connection.nil?
    @connection = Net::HTTP.new self.uri.host, self.uri.port
    @connection.use_ssl = (uri.scheme == 'https')
    @connection.start 
    @connection
  end
end


# A class to encapsulate the difference between gem states
class SpecDiff < Struct.new(:dep, :spec, :gemdata, :versions)
  
  # Configure the diff
  def initialize(*args)
    super
    # Check for prerelease - Gem rules are that a letter indicates a prerelease
    # See http://rubygems.rubyforge.org/rubygems-update/Gem/Version.html#method-i-prerelease-3F
    @prerelease = version_in_use =~ /[a-zA-Z]/
  end
  
  # Return a :month1, :month6, :year1, :more depending on the
  # build age of the available version
  def build_age
    build_date = version_build_date(version_in_use)
    return :none if build_date.nil?
    days = ((Time.now.utc - build_date)/(24 * 60 * 60)).round
    case
    when days < 31  then :month1
    when days < 182 then :month6
    when days < 366 then :year1
    else :more
    end
  end

  # Classify this as :current, :update or :obsolete
  def classify
    case
    when (version_available == version_in_use) then :current
    when (dep.match?(name, version_available)) then :update
    else :obsolete
    end
  end
  
  def prerelease?; @prerelease; end
  
  def name; dep.name; end
  
  # Is there a suggested version - e.g. if you're using rails 3.0.8, the most
  # current might be 3.1.0. However, the suggested version would be 3.0.10 --
  # this will suggest the best version within your current minor version tree.
  # May return nil if you're at the current suggestion, or if there is no
  # reasonable match
  def suggest
    match = nil
    head = version_in_use.rpartition('.').first
    versions.sort_by { |v| v['built_at'] }.reverse.each do |ver|
      ver = ver['number']
      match = ver and break if ver.start_with?(head)
    end
    (match == version_in_use) || (match == version_available) ? nil : match
  end
  
  # String representation is the basic spec form 'gename (version)', 
  # with a start appended for prereleases.
  def to_s
    "#{spec}#{prerelease? ? '*' : ''}"
  end
  
  # Return the version data for a given string
  def version_data(version)
    return nil if versions.nil? || versions.empty?
    version = versions.find { |v| v['number'] == version }
  end
  
  # Return the build date for a given version string (e.g. '1.2.1')
  def version_build_date(version)
    return nil if versions.nil? || versions.empty?
    data = version_data(version)
    return nil if data.nil?
    version_date = data['built_at']
    version_date.nil? ? nil : Time.parse(version_date)
  end
  
  # Best version available according to RubyGems data
  def version_available
    return gemdata["version"].to_s unless prerelease?
    
    # Depends if it's a prerelease or not
    prereleases = versions.select { |v| v['prerelease']}.map { |v| v['number'] }
    prereleases.first # Big Assumption, but appears correct on data so far
  end
  
  # The version currently in use according to the lockfile
  def version_in_use; spec.version.to_s; end
  
end
