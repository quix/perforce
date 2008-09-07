
require 'rubygems'
require 'perforce'
require 'pp'

def report(desc)
  if block_given?
    puts "#{desc}:"
    pp yield
  else
    puts "#{desc}."
  end
  puts
end

def with_dummy_file(file)
  File.open(file, "w") { |out| out.puts "test" }
  begin
    yield file
  ensure
    File.unlink(file)
  end
end

perforce = Perforce.new

report("Server info") {
  perforce.run("info").first
}

root = perforce.root

report("Client root") {
  root
}

report("Pending changelists") {
  perforce.pending_changelists
}

perforce.chdir(root) {
  changelist = perforce.new_changelist("**RUBY TEST**")

  report("Created test changelist: ##{changelist.number}")

  report("Pending changelists") {
    perforce.pending_changelists
  }

  with_dummy_file("dummy-test-file-for-ruby-perforce.txt") { |file|
    changelist.add_files([file])

    report("Added a dummy file to the changelist")
    
    report("Files in changelist") {
      changelist.files
    }
    
    report("Description for this changelist") {
      changelist.description
    }
    
    report("Status of this changelist") {
      changelist.status
    }
    
    changelist.revert_files([file])
    
    report("Reverted the dummy file")
    
    report("Files in changelist") {
      changelist.files
    }

    changelist.delete
    
    report("Deleted changelist")
    
    report("Pending changelists") {
      perforce.pending_changelists
    }
  }
}
  
