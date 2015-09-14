module ARKWEB

# The Interface class controls interaction with an ARKWEB site, including site
# initialization and rendering. The Interface class also implements the
# command line interface for ARKWEB
class Interface

  # Initialize a new Interface object
  def initialize()
    @root    = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
    @project = 'ARKWEB'
    @freeze  = self.root('freeze.yaml')

    if File.exist?(@freeze)
      f = YAML.load_file(@freeze)
      @version  = f['version']
    else
      @version  = Ark::Git.version(default: 'DEV VERSION')
    end
    @identity = Ark::Git.version_line(default: @version, project: @project)

    @conf = Ark::CLI.report do |s|
      s.name 'ark'
      s.desc 'ARKWEB is a static website compiler'
      s.args 'site'

      s.opt :verbose, :v,
      desc: 'Run verbosely'

      s.opt :quiet, :q,
      desc: 'Suppress all messages'

      s.opt :output, :o,
      args: 'path',
      desc: 'Directory to write rendered files to'

      s.opt :clobber, :l,
      desc: "Remove any output before rendering"

      s.opt :clean, :c,
      desc: 'Remove temporary files after rendering'

      s.opt :validate, :a,
      desc: 'Validate rendered HTML'

      s.opt :minify, :m,
      desc: 'Minify CSS and Javascript on rendering'

      s.raise_on_trailing
    end

    @sitepath = @conf.arg(:site)

    Ark::Log::Conf[:verbose] = @conf.opt(:verbose)
    Ark::Log::Conf[:quiet]   = @conf.opt(:quiet)

    require 'yui/compressor' if @conf.opt(:minify)
    require 'w3c_validators' if @conf.opt(:validate)
  end

  attr_reader :version

  attr_reader :conf

  attr_reader :identity

  def root(*args)
    if args.empty?
      return @root
    else
      return File.join(@root, *args)
    end
  end

  # Render an existing site directory, generating HTML files to the output
  # directory. This is called from Interface#run
  def render
    site = Site.new(self, @sitepath)
    if @conf.opt(:clobber)
      [:render, :cache, :tmp].each do |p|
        if File.directory?(site.out(p))
          dbg "Clobbering directory: #{site.out(p)}"
          FileUtils.rm_r(site.out(p))
        end
      end
    end
    site.engine.write_site
    if @conf.opt(:clean)
      [:cache, :tmp].each do |p|
        if File.directory?(site.out(p))
          dbg "Cleaning directory: #{site.out(p)}"
          FileUtils.rm_r(site.out(p))
        end
      end
    end
    msg "Done! Wrote site to: #{site.out(:render)}"
  end

  # Initialize a new site at the given path by copying the skeletal site
  # structure there. This is called from Interface#run
  def init
    msg "Initializing site: #{@sitepath}"
    FileUtils.mkdir_p(@sitepath)
    target = self.root('skel', '*')
    FileUtils.cp_r(Dir[target], @sitepath)
    msg "Done! Initialized site: #{@sitepath}"
  end

  # Either render an existing site or initialize a new site
  def run
    if File.directory?(@sitepath)
      msg "Rendering site at '#{@sitepath}'"
      self.render
    elsif !File.exist?(@sitepath)
      msg "Initializing new site at '#{@sitepath}'"
      self.init
    else
      wrn "#{@sitepath} is a file. Please provide a path to an existing site
      directory, or a nonexistant path to be created."
    end
  end

end # class Interface
end # module ARKWEB

