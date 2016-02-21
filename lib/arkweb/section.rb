module ARKWEB

class Section
  include HasContent

  SectionHeader = 'section.yaml'

  def initialize(site, input_path)
    @site = site
    @path = Path.new(@site, input_path, @site.output.root, relative: true)

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

    @title = self.conf(:title)
    @desc = self.conf(:desc) || ''

    init_contents

    # Order pages by ctime and give them an index
    @ordered_pages = Hash[@pages.sort {|p1,p2| p1.last <=> p2.last }]
    @ordered_pages.each_with_index do |pair,i|
      pair.last.index = i + 1
    end
  end
  attr_reader :site
  attr_reader :path
  attr_reader :title
  attr_reader :desc
  attr_reader :ordered_pages

  private

  def init_contents
    @pages = ClosedHash.new
    @sections = ClosedHash.new

    # Get pages
    @path.input.glob(Site::Types.pages).each do |path|
      page = Page.new(@site, path, self)
      @pages[page.path.name] = page
    end

    if self.conf(:autoindex) && !self.has_page?('index')
      @pages['index'] = Page.new(@site, @site.templates.autoindex, self, autoindex: true)
    end

    # Get sections
    @path.input.glob('*/').reject do |path|
      (self.root? && path.basename.to_s == Site::InputARKWEB) || path.to_s[/\.page\/*$/]
    end.each do |path|
      section = Section.new(@site, path)
      @sections[section.path.name] = section
    end

    @site.register_section(self)
  end

  public

  def conf(key)
    key = key.to_sym
    unless @conf.has_key?(key)
      raise ArgumentError "No such configuration: #{key}"
    end
    return @conf[key]
  end

  def has_index?
    return self.has_page?('index') || self.conf(:autoindex)
  end

  def root?
    return @path.link == Pathname.new('/')
  end

  def link_to(**attr)
    if self.has_index?
      return HTML.link_section(self, **attr)
    else
      return HTML.span(attr[:text] || @title, **attr)
    end
  end

  def inspect
    return "#<AW::Section:#{@path.link}>"
  end
end

end # module ARKWEB

