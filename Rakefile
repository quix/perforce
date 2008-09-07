
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'

$VERBOSE = nil
require 'rdoc/rdoc'
$VERBOSE = true

require 'fileutils'
include FileUtils

gemspec = eval(File.read("perforce.gemspec"))
doc_dir = "html"

task :clean => [:clobber, :clean_doc]

task :clean_doc do
  rm_rf(doc_dir)
end

task :test do
  require Dir["test/test_*.rb"]
end

task :package => :clean

Rake::GemPackageTask.new(gemspec) { |t|
  t.need_tar = true
}

task :doc => :clean_doc do 
  files = ["README", "lib/perforce.rb"]

  options = [
    "-o", doc_dir,
    "--title", "Perforce: #{gemspec.summary}",
    "--main", "README"
  ]

  RDoc::RDoc.new.document(files + options)
end

task :publish => :doc do
  Rake::RubyForgePublisher.new('perforce', 'quix').upload
end

task :release => [:package, :publish]
