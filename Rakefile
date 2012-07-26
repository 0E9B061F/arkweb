require 'rake'
require 'rdoc/task'
require 'rubygems/package_task'
require 'rspec/core/rake_task'
require 'fileutils'
require 'erb'

load 'lib/arkweb-3.rb'



class Helper
  def initialize
    @home = Dir.pwd
    @git_version = ENV['version'] || `git tag`.lines.select {|l| l[/^v\d\.\d$/] }.last.strip
    @git_series  = `git tag`.lines.select {|l| l[/^series-/] }.last.strip
  end
  attr_reader :home, :git_version, :git_series
  def name
    File.basename(@home)
  end
  def return
    Dir.chdir(@home)
  end
  def long_version
    "#{@git_version[1..-1]}.0"
  end
  def gem_name
    AW::Project['name'].downcase
  end
  def gem_version
    "#{self.gem_name}-#{self.long_version}"
  end
  def pkg_name
    "ruby-#{self.gem_name}"
  end
  def pkg_version
    "#{self.pkg_name}-#{self.long_version}"
  end
  def version_dir
    File.join(self.home, 'v', self.long_version)
  end
  def gem
    "#{self.gem_version}.gem"
  end
  def pkg
    "#{self.pkg_version}-1-any.pkg.tar.xz"
  end
  def src
    "#{self.pkg_version}-1.src.tar.gz"
  end
  def gem_file
    File.join(H.version_dir, self.gem)
  end
  def pkg_file
    File.join(H.version_dir, self.pkg)
  end
  def src_file
    File.join(H.version_dir, self.src)
  end
  def gem_link
    File.join(self.home, 'v', 'gem')
  end
  def pkg_link
    File.join(self.home, 'v', 'pkg')
  end
  def src_link
    File.join(self.home, 'v', 'src')
  end

  def set_version(v)
    @git_version = v
  end
end
H = Helper.new



RSpec::Core::RakeTask.new 'spec' do |t|
  t.pattern = './spec/*.rb'
end

spec = Gem::Specification.new do |s|
  s.name = AW::Project['name'].downcase
  s.version = H.long_version
  s.author      = 'nn'
  s.email       = 'nn@studio25.org'
  s.description = 'ARKWEB the _inscrutable_ ,
                   '
  s.summary     = 'ARKWEB the _inscrutable_ web publisher'
  s.homepage    = 'http://studio25.org/projects/arkweb'

  s.files        = Dir.glob("{bin,lib,templates}/**/*") + %w(LICENSE README freeze.yaml)
  s.bindir      = 'bin'
  s.executables  = ['ark']
  s.require_path = 'lib'
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

Rake::RDocTask.new do |rd|
  rd.main       = 'README'
  rd.rdoc_dir   = 'doc'
  rd.title      = "ARKWEB #{H.long_version} '#{AW::Project['codename']}'"
  rd.rdoc_files = Dir['bin/*'] + Dir['lib/*']
end

desc "Run arkweb"
task :run do
  site = ARKWEB::Site.new('test/site')
  site.compile()
  site.deploy()
end

desc "Clone a temporary working repository and checkout latest version"
task :checkout do
  puts "\n Cloning checkout version #{H.git_version} ".ljust(80, '=')
  Dir.chdir('/tmp')
  FileUtils.rm_r(H.name) if File.directory?(H.name)
  `git clone #{H.home}`
  Dir.chdir(H.name)
  `git checkout #{H.git_version}`
end

desc "Freeze version info"
task :freeze do
  pr = YAML.load_file('project.yaml')
  pr['version']  = H.git_version
  pr['codename'] = H.git_series
  File.open('freeze.yaml', 'w') do |f|
    YAML.dump(pr, f)
  end
end

desc "Clone a temporary work area, checkout the latest version, freeze version info and build the gem"
task :buildgem => [:checkout, :freeze, :gem] do
  puts "\n Building gem and copying to . ".ljust(80, '=')
  FileUtils.mv("pkg/#{H.gem}", '.')
end

desc "Generate a PKGBUILD for the latest version, to be used with makepkg"
task :pkgbuild do
  puts "\n Generating PKGBUILD ".ljust(80, '=')
  @version = H.long_version
  FileUtils.cp('PKGBUILD.erb','PKGBUILD')
  File.open('PKGBUILD.erb', 'r') do |f|
    erb = ERB.new(f.read)
    pb = erb.result(binding)
    File.open('PKGBUILD', 'w') {|o| o.write(pb) }
  end
  @md5     = `makepkg -g`
  File.open('PKGBUILD.erb', 'r') do |f|
    erb = ERB.new(f.read)
    pb = erb.result(binding)
    File.open('PKGBUILD', 'w') {|o| o.write(pb) }
  end
end

desc "Run makepkg, generating a .pkg. file for use with pacman"
task :makepkg => :pkgbuild do
  puts "\n MAKEPKG ".ljust(80, '=')
  system('makepkg -fc')
end

desc "Generate a source tar suitable for upload to the AUR"
task :aur do
  puts "\n TAURBALL ".ljust(80, '=')
  system('makepkg -f --source')
end

desc "Scan generated PKGBUILD and .pkg. using namcap"
task :namcap do
  puts "\n NAMCAP ".ljust(80, '=')
  system('namcap PKGBUILD')
  system("namcap #{H.pkg}")
end

desc "Perform full packaging task, producing a gem, Arch Linux pkg and AUR src tar."
task :pack => [:buildgem, :makepkg, :aur, :namcap] do
  FileUtils.rm_r(H.version_dir) if File.directory?(H.version_dir)
  FileUtils.mkdir_p(H.version_dir)
  FileUtils.cp([H.pkg, H.src, H.gem], H.version_dir)
  H.return
  FileUtils.ln_s(H.pkg_file, H.pkg_link, :force => true)
  FileUtils.ln_s(H.gem_file, H.gem_link, :force => true)
  FileUtils.ln_s(H.src_file, H.src_link, :force => true)
end

desc "Uninstall arkweb if installed"
task :uninstall do
  system("pacman -Q #{H.pkg_name} && sudo pacman -Rdd #{H.pkg_name}")
end
desc "Install pacman package, according to the version env variable"
task :install do
  system("sudo pacman -U #{H.pkg_file}")
end

