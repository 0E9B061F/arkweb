module ARKWEB

class Application
  def initialize
    @root = Pathname.new(__FILE__).parent.parent.parent.realpath
    @project = 'ARKWEB'
    @freeze  = self.root('freeze.yaml')

    if @freeze.exist?
      f = YAML.load_file(@freeze)
      @version  = f['version']
    else
      @version  = ARK::Git.version(@root, default: 'DEV VERSION')
    end
    @identity = ARK::Git.version_line(@root, default: @version, project: @project)
  end
  attr_reader :project
  attr_reader :version
  attr_reader :identity

  def root(*args)
    if args.empty?
      return @root
    else
      return @root.join(*args)
    end
  end

  def inspect
    return "#<AW::Application:#{@identity}>"
  end
end

end # module ARKWEB

