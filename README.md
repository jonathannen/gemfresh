# Gemfresh
Scans your bundler Gemfile and lets you know how up-to-date your gems are.

## Usage:
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

## License
MIT Licensed. See MIT-LICENSE.txt for more information.