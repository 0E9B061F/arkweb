module ARKWEB

class Section

  IncludeFileName = 'include.yaml'

  def initialize(site, path)
    @site = site
    @path = path

    # Get all pages in this section
    page_glob = File.join(@path, Site::Types[:pages])
    @pages = Dir[page_glob].map do |p|
      Page.new(@site, p, self)
    end

    # Look for an include file
    include_file = File.join(@path, IncludeFileName)
    if File.exist?(include_file)
      @inclusions = YAML.load_file(include_file)
    else
      @inclusions = {}
    end

    # Order pages by ctime and give them an index
    @ordered_pages = @pages.sort {|a,b| a <=> b }
    @ordered_pages.each_with_index do |page,i|
      page.index = i + 1
    end

    # Get a title for this section
    @title = File.basename(@path).capitalize()

    # Path-related stuff
    @relative = Pathname.new(@path).relative_path_from(Pathname.new(@site.root))
    @output_path = File.join(@site.output[:render], @relative)
  end
  attr_reader :site, :path, :pages, :title, :ordered_pages
  attr_reader :inclusions
  attr_reader :output_path

  def page_count()
    return @pages.length()
  end

  def link_to(**options)
    text  = options[:text]  || @title
    id    = options[:id]    || nil
    klass = options[:class] || nil
    id    = %Q( id="#{id}")       if id
    klass = %Q( class="#{klass}") if klass
    return %Q(<a#{id}#{klass} href="#{@relative}">#{text}</a>)
  end
end

end # module ARKWEB

