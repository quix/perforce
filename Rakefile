
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'

$VERBOSE = nil
require 'rdoc/rdoc'
$VERBOSE = true

require 'fileutils'
include FileUtils

gemspec = eval(File.read("perforce.gemspec"))
doc_dir = "html"

(class << self ; self ; end).instance_eval {
  define_method(:clean_doc) {
    rm_rf(doc_dir)
  }
}

task :clean => [:clobber, :clean_doc]

task :clean_doc do
  clean_doc
end

task :test do
  require Dir["test/test_*.rb"]
end

task :gem => :clean

Rake::GemPackageTask.new(gemspec) {
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

task :release do
  Rake::Task[:publish].invoke
  clean_doc # force second invocation
  Rake::Task[:gem].invoke
end
