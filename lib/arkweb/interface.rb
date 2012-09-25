module ARKWEB
class Interface

# TODO
#  def self.load_plugins
#    if Conf[:plugin]
#      plugins = Conf[:plugin].split(',')
#      plugins.each do |plugin|
#        name = File.basename(plugin).sub(/\.[^\.]+?$/,'').capitalize
#        load plugin
#        klass = eval "ARKWEB::#{name}"
#        ARKWEB.register_plugin(klass)
#      end
#    end
#  end

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

  def self.init(path)
    msg "Initializing site: #{path}"
    FileUtils.mkdir_p(path)
    target = root('skel', '*')
    FileUtils.cp_r(Dir[target], path)
    msg "Done! Initialized site: #{path}"
  end

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

