module ARKWEB

class Section

  IncludeFileName = 'include.yaml'

  def initialize(site, input_path)
    @site = site
    @path = Path.new(@site, input_path, :root, relative: true)

    # Get all pages in this section
    @pages = @path.input.glob(Site::Types[:pages]).map do |p|
      Page.new(@site, p, self)
    end

    # Look for an include file
    include_file = @path.input.join(IncludeFileName)
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
    @title = @path.input.basename.to_s.capitalize
  end
  attr_reader :site
  attr_reader :path
  attr_reader :pages
  attr_reader :title
  attr_reader :ordered_pages
  attr_reader :inclusions

  def page_count
    return @pages.length
  end

  def link_to(**options)
    text  = options[:text]  || @title
    id    = options[:id]    || nil
    klass = options[:class] || nil
    id    = %Q( id="#{id}")       if id
    klass = %Q( class="#{klass}") if klass
    return %Q(<a#{id}#{klass} href="#{@relative}">#{text}</a>)
  end

  def inspect
    return "#<Section:#{@path.link}>"
  end
end

end # module ARKWEB

