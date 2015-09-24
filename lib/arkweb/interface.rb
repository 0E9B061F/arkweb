module ARKWEB

# The Interface class controls interaction with an ARKWEB site, including site
# initialization and rendering. The Interface class also implements the
# command line interface for ARKWEB
class Interface

  # Initialize a new Interface object
  def initialize(args=ARGV)
    msg "Initializing ARKWEB"
    @app = Application.new

    @conf = Ark::CLI.report(args) do |s|
      s.name 'ark'
      s.desc 'ARKWEB is a static website compiler'
      s.args "sitepath:#{Dir.pwd}"
      s.version @app.identity

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

    @sitepath = Pathname.new(@conf.arg(:sitepath))

    Ark::Log::Conf[:verbose] = @conf.opt(:verbose)
    Ark::Log::Conf[:quiet]   = @conf.opt(:quiet)
  end

  attr_reader :version

  attr_reader :identity

  # Render an existing site directory, generating HTML files to the output
  # directory. This is called from Interface#run
  def render
    site = Site.new(@sitepath, @conf)
    msg "Assembling site: #{site.conf(:title)}"
    site.engine.write_site
    msg "Done! Wrote site to: #{site.out(:root)}"
  end

  # Initialize a new site at the given path by copying the skeletal site
  # structure there. This is called from Interface#run
  def init
    msg "Initializing site: #{@sitepath}"
    @sitepath.mkpath
    target = @app.root.join('skel')
    FileUtils.cp_r(target.children, @sitepath)
    msg "Done! Initialized site: #{@sitepath}"
  end

  # Either render an existing site or initialize a new site
  def run
    if @sitepath.directory?
      self.render
    elsif !@sitepath.exist?
      self.init
    else
      wrn "#{@sitepath} is a file. Please provide a path to an existing site
      directory, or a nonexistant path to be created."
    end
  end

end # class Interface
end # module ARKWEB



