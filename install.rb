
require 'rbconfig'
require 'fileutils'

include FileUtils

source = "lib/perforce.rb"
dest = File.join(Config::CONFIG["sitelibdir"], File.basename(source))

if ARGV.include? "--uninstall"
  if File.exist? dest
    puts "delete #{dest}"
    rm_f dest
  end
else
  puts "#{source} --> #{dest}"
  install source, dest
end
