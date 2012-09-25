module ARKWEB
class Site

  Paths = {
    :header   => "header.yaml",
    :pages    => "*.page",
    :page_erb => "page.html.erb",
    :site_erb => "site.html.erb",
    :output   => "html",
    :sass     => "*.{scss,sass}",
    :css      => "*.css",
    :images   => "img",
    :tmp      => "tmp",
    :cache    => "cache"
  }
  FontService = {
    :google => lambda {|fonts|
      url = 'http://fonts.googleapis.com/css?family='
      fonts = fonts.join('|')
      return [url + fonts]
    },
    :fontsquirrel => lambda {|fonts|
      fonts.map {|font| "#{font}.css" }
    }
  }
  
  def initialize(root)
    raise BrokenSiteError unless File.directory?(root)
    @root = root
    @name = File.basename(root)
    @paths = make_path
    
    begin
      header = YAML.load_file(@paths[:header])
    rescue => e
      raise BrokenSiteError,
      "While loading site '#{@root}': #{e}\nHeader file '#{@paths[:header]}' is missing or malformed."
    end

    @paths[:output] = Conf[:output] || header['output'] || @paths[:output]
    @paths[:tmp]    = header['tmp'] || @paths[:tmp]
    @paths[:images] = header['images'] || @paths[:images]

    @author    = header['author']
    @title     = header['title']
    @desc      = header['desc'] || header['description']
    @tags      = header['tags'] || header['keywords']
    @xuacompat = header['xuacompat'] || false
    @keywords  = @tags ? @tags.join(', ') : ''
    @webfonts  = {'google' => [], 'fontsquirrel' => []}
    @webfonts  = @webfonts.merge(header['webfonts']) if header['webfonts']
    @styles    = header['styles']

    if @webfonts
      if @webfonts['fontsquirrel']
        @webfonts['fontsquirrel'].map! {|f| f.tr(' ', '-') }
      end
      urls = []
      @webfonts.each do |service,fonts|
        service = service.to_sym
        if FontService[service]
          urls += FontService[service][fonts]
        else
          wrn "Unknown font provider '#{service}' for fonts: #{fonts}"
        end
      end
      @styles += urls
    end

    @files = {}
    @files[:pages]  = Dir[@paths[:pages]]
    @files[:images] = Dir[@paths[:images]]
    @files[:css]    = Dir[@paths[:css]]
    @files[:sass]   = Dir[@paths[:sass]]

    [:output, :tmp, :images, :cache].each do |dir|
      FileUtils.mkdir_p(@paths[dir])
    end

    @engine = Engine.new(self)
  end
  attr_reader :root, :name, :paths
  attr_reader :author, :title, :desc, :tags, :keywords, :xuacompat
  attr_reader :webfonts, :styles, :files, :engine

  private

  # Create site-relative paths from Paths
  def make_path
    path = {}
    Paths.each do |name, p|
      path[name] = File.join(@root, p)
    end
    return path
  end

  public

  # Convenience method for accessing #paths
  def [](key)
    @paths[key]
  end

end # class Site
end # module ARKWEB

