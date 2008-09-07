
require 'thread'
require 'P4'

# 
# A connection to a perforce server.
#
class Perforce
  CYGWIN = (RUBY_PLATFORM =~ %r!cygwin!) #:nodoc:

  #
  # Connect to a perforce depot.
  #
  # The argument <em>spec</em> is a hash of <em>(method, value)</em>
  # pairs sent to the underlying P4 object.
  #
  # The given values override the P4PORT, P4CLIENT, etc. environment
  # variables.
  #
  # Example:
  #
  #   #
  #   # This calls P4#user=, P4#password=, P4#client=, P4#port= with
  #   # these values, then calls P4#connect.
  #   #
  #   Perforce.new(
  #     :user => "iggy_fenton",
  #     :password => "<password or ticket number>",
  #     :client => "iggy_fenton_project",
  #     :port => "server_name:1666")
  #
  def initialize(spec = {})
    #
    # Remove PWD during creation to avoid some troubles.  The user
    # probably wants perforce to use the absolute path of the current
    # directory, not a path infected by symlinks.
    # 
    # Since ~/project was a symlink to my perforce-based project,
    # perforce would not run when I got there via "cd project" from my
    # home directory.
    #
    @p4 = 
      if self.class.use_pwd_symlinks
        P4.new
      else
        Thread.exclusive {
          previous_pwd = ENV["PWD"]
          ENV.delete("PWD")
          begin
            P4.new
          ensure
            if previous_pwd
              ENV["PWD"] = previous_pwd
            end
          end
        }
      end
    spec.each_pair { |key, value|
      @p4.send("#{key}=", value)
    }
    unless spec.has_key?(:user)
      # guess user
      @p4.user = [
        ENV["USER"],
        ENV["USERNAME"],
      ].select { |name|
        name != nil and name != ""
      }.first.tap { |user|
        unless user 
          raise "Could not determine username"
        end
      }
    end
    @p4.exception_level = P4::RAISE_ERRORS
    @p4.connect
  end

  #
  # The underlying P4 object from the P4Ruby package.
  #
  def p4
    @p4
  end

  #
  # Create a Changelist with the given description.
  #
  def new_changelist(desc)
    input = {
      "Change" => "new",
      "Description" => desc,
    }

    number =
      run_with_input(input, "change", "-i").
      first.
      match(%r!\AChange (\d+) created\.!).
      captures.
      first

    Changelist.new(self, number)
  end
  
  #
  # Revert these files.
  #
  def revert_files(files)
    unless files.empty?
      run("revert", *files)
    end
  end

  #
  # Return the pending changelists (as Changelist objects).
  #
  def pending_changelists
    command = %W(changelists -u #{@p4.user} -c #{@p4.client} -s pending)
    run(*command).map { |elem|
      Changelist.new(self, elem["change"].to_i)
    }
  end

  #
  # Delete all empty changelists.
  #
  def delete_empty_changelists
    pending_changelists.each { |changelist|
      changelist.delete
    }
  end

  #
  # Calls <code>run("sync", *args)</code>
  #
  def sync(*args)
    run("sync", *args)
  end

  #
  # Edit and submit files in one step.
  #
  # Example:
  #   perforce.edit_and_submit("remove trailing whitespace", files) {
  #     #
  #     # Do stuff with the files.
  #     # ...
  #     #
  #   }
  #   #
  #   # Changes are submitted when the block ends.
  #   #
  #
  def edit_and_submit(changelist_description, files)
    changelist = new_changelist(changelist_description)
    changelist.add_files(files)
    yield
    changelist.submit
  end

  #
  # Client root directory.
  #
  def root
    dir = run(*%w(client -o)).first["Root"]
    if CYGWIN
      unix_dir = Util.unix_path(dir)
      if dir != unix_dir
        add_unix_root
      end
      unix_dir
    else
      dir
    end
  end

  if CYGWIN
    #
    # <em>Cygwin-only.</em>
    #
    # Add a UNIX-style AltRoot.
    #
    # This allows P4Win and cygwin to work in the same client spec.
    #
    def add_unix_root #:nodoc:
      client = run(*%w(client -o)).first
      alt_roots = client["AltRoots"]
      if alt_roots and alt_roots.include?(Util.unix_path(client["Root"]))
        # has proper alt root
      else
        client["AltRoots"] =
          alt_roots.to_a + [Util.unix_path(client["Root"])]
        run_with_input(client, "client", "-i")
        puts("Note: added unix AltRoot to client")
      end
    end
  end

  #
  # Change working directory (locally and remotely).
  #
  def chdir(dir)
    previous_dir = File.expand_path(".")
    Dir.chdir(dir) {
      @p4.cwd = File.expand_path(".")
      yield
    }
    @p4.cwd = previous_dir
  end

  #
  # Call P4#input(input) and then P4#run(*args)
  #
  def run_with_input(input, *args)
    @p4.input = input
    run(*args)
  end

  #
  # Run a general p4 command.
  #
  # Example:
  #   puts "Your server version is: "
  #   puts perforce.run("info").first["serverVersion"]
  #
  def run(*args)
    go = lambda {
      @p4.run(*args).tap {
        puts(@p4.warnings)
      }
    }
    if CYGWIN
      begin
        go.call
      rescue P4Exception
        if @p4.connected?
          # maybe unix root is not present; try again
          add_unix_root
          go.call
        else
          raise
        end
      end
    else
      # not CYGWIN
      go.call
    end
  end

  if CYGWIN
    module Util #:nodoc:
      def unix_path(dos_path) #:nodoc:
        escaped_path = dos_path.sub(%r!\\+\Z!, "").gsub("\\", "\\\\\\\\")
        `cygpath #{escaped_path}`.chomp
      end
      extend self
    end
  end

  @use_pwd_symlinks = true
  class << self
    #
    # Whether the current directory as reported to the perforce server
    # can contain symlinks.  Default is false.
    #
    attr_accessor :use_pwd_symlinks
  end

  #
  # A Perforce changelist.
  #
  # Use Perforce#new_changelist to create a new changelist.
  #
  class Changelist
    def initialize(perforce, number) #:nodoc:
      @perforce = perforce
      @number = number
    end

    #
    # Changelist number.
    # 
    attr_reader :number

    # 
    # Add files to this Changelist.
    # 
    # This is used for both editing files and adding new files.
    # 
    def add_files(files)
      unless files.empty?
        @perforce.run("edit", "-c", @number, *files)
        @perforce.run("add", "-c", @number, *files)
      end
    end
    
    # 
    # Revert these files in this changelist.
    # 
    def revert_files(files)
      unless files.empty?
        @perforce.run("revert", "-c", @number, *files)
      end
    end

    # 
    # Open files for deletion.  This action is added to the changelist.
    # 
    def delete_files(files)
      unless files.empty?
        @perforce.run("delete", "-c", @number, *files)
      end
    end

    # 
    # Submit this Changelist.
    # 
    def submit
      revert_unchanged_files
      if empty?
        delete
      else
        @perforce.run("submit", "-c", @number)
      end
    end

    # 
    # True if there are no files in this Changelist.
    # 
    def empty?
      not @perforce.run("describe", @number).first.has_key?("depotFile")
    end

    # 
    # If empty, delete this Changelist.
    # 
    def delete
      if empty?
        @perforce.run("change", "-d", @number)
      end
    end

    # 
    # Info hash for this Changelist.
    # 
    def info
      @perforce.run("change", "-o", @number).first
    end
    
    # 
    # Files in this Changelist.
    # 
    def files
      info["Files"].to_a
    end

    # 
    # Description of this changelist
    # 
    def description
      info["Description"]
    end

    # 
    # Status of this changelist
    # 
    def status
      info["Status"]
    end

    # 
    # Revert unchanged files in this Changelist.
    # 
    def revert_unchanged_files(in_files = nil)
      files =
        if in_files.nil?
          self.files
        else
          in_files
        end

      unless files.empty?
        @perforce.run("revert", "-a", "-c", @number, *files)
      end
    end
  end
end

# version < 1.8.7 compatibility
unless respond_to? :tap
  module Kernel #:nodoc:
    def tap #:nodoc:
      yield self
      self
    end
  end
end
