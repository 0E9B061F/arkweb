module ARKWEB

class Section

  IncludeFileName = 'include.yaml'
  SectionHeader = 'section.yaml'

  def initialize(site, input_path)
    @site = site
    @path = Path.new(@site, input_path, :root, relative: true)

    # Get all pages in this section
    @pages = @path.input.glob(Site::Types[:pages]).map do |p|
      Page.new(@site, p, self)
    end

    if self.root?
      title = "Home"
    else
      title = @path.link.basename.to_s.capitalize
    end

    @conf = {
      :title => title,
      :desc => false,
      :include => {},
      :autoindex => false
    }
    # Look for a section header file
    header_file = @path.input.join(SectionHeader)
    if header_file.exist?
      header = YAML.load_file(header_file)
      header = Hash[header.map {|k,v| [k.to_sym, v] }]
      @conf = @conf.merge(header) {|k,old,new| new && !new.to_s.empty? ? new : old }
    end

    # Order pages by ctime and give them an index
    @ordered_pages = @pages.sort {|a,b| a <=> b }
    @ordered_pages.each_with_index do |page,i|
      page.index = i + 1
    end

    @title = self.conf(:title)
    @desc = self.conf(:desc) || ''
  end
  attr_reader :site
  attr_reader :path
  attr_reader :title
  attr_reader :desc
  attr_reader :pages
  attr_reader :ordered_pages

  def conf(key)
    key = key.to_sym
    unless @conf.has_key?(key)
      raise ArgumentError "No such configuration: #{key}"
    end
    return @conf[key]
  end

  def root?
    return @path.link == Pathname.new('/')
  end

  def page_count
    return @pages.length
  end

  def link_to(**options)
    text  = options[:text]  || @title
    id    = options[:id]    || nil
    klass = options[:klass] || nil
    id    = %Q( id="#{id}")       if id
    klass = %Q( class="#{klass}") if klass
    return %Q(<a#{id}#{klass} href="#{@path.link}">#{text}</a>)
  end

  def inspect
    return "#<AW::Section:#{@path.link}>"
  end
end

end # module ARKWEB

