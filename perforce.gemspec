
Gem::Specification.new { |t| 
  t.name = "perforce"
  t.version = "1.0.2"
  t.summary = "Streamlined wrapper for p4ruby"
  t.author = "James M. Lawrence"
  t.email = "quixoticsycophant@gmail.com"
  t.rubyforge_project = "perforce"
  t.homepage = "perforce.rubyforge.org"
  t.has_rdoc = true
  t.extra_rdoc_files = ['README']
  t.rdoc_options += %w{--title Perforce --main README}
  t.add_dependency('p4ruby')
  t.files = %w{
    README
    perforce.gemspec
    install.rb
    lib/perforce.rb
    test/test_main.rb
  }
}

