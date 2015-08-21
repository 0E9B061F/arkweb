module ARKWEB

# The Interface class implements arkweb's command line interface
class Interface

	# Process an existing site directory, generating HTML files to the output
	# directory. This is called from Interface#run
  def self.process(path)
    msg "Processing site: #{path}"
    site = Site.new(path)
    if Conf[:clobber]
      [:output, :cache, :tmp].each do |p|
        if File.directory?(site[p])
          glob = File.join(site[p], '*')
          dbg "Clobbering directory: #{site[p]}"
          FileUtils.rm_r(Dir[glob])
        end
      end
    end
    site.engine.write_site
    if Conf[:clean]
      [:cache, :tmp].each do |p|
        if File.directory?(site[p])
          glob = File.join(site[p], '*')
          dbg "Cleaning directory: #{site[p]}"
          FileUtils.rm_r(Dir[glob])
        end
      end
    end
    msg "Done! Wrote site to: #{site[:output]}"
  end

	# Initialize a new site at the given path by copying the skeletal site
	# structure there. This is called from Interface#run
  def self.init(path)
    msg "Initializing site: #{path}"
    FileUtils.mkdir_p(path)
    target = root('skel', '*')
    FileUtils.cp_r(Dir[target], path)
    msg "Done! Initialized site: #{path}"
  end

	# Either prcoess an existing site or initialize a new site
  def self.run(path=nil)
    msg Version
    if path && File.directory?(path)
      self.process(path)
    elsif path && !File.exist?(path)
      self.init(path)
    else
      wrn "#{path} is a file. Please provide a path to an existing site
      directory, or a nonexistant path to be created."
    end
  end

end # class Interface
end # module ARKWEB

