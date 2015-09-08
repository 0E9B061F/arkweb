require 'rake'
require 'rdoc/task'
require 'rubygems/package_task'
require 'rspec/core/rake_task'
require 'fileutils'
require 'erb'
require 'digest'



class Helper

  Project = 'ARKWEB'

  def initialize
    @home = Dir.pwd

    v = `git describe --tags`.strip.tr('-', '.')
    c = 2 - v.count('.')
    if c > 0
      v = v + ('.0' * c)
    else
      v.sub!(/\.[^\.]+$/, '')
    end
    if !`git status --porcelain`.empty?
      v = v + '.dev'
    end
    @version = v
  end

  attr_reader :home, :version

  def name
    Project.downcase
  end

  def return
    Dir.chdir(@home)
  end

  def gem_version
    "#{self.name}-#{@version}"
  end

  def pkg_name
    "ruby-#{self.name}"
  end
  def pkg_version
    "#{self.pkg_name}-#{@version}"
  end

  def version_dir
    File.join(self.home, 'v', @version)
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
    File.join(self.version_dir, self.gem)
  end
  def pkg_file
    File.join(self.version_dir, self.pkg)
  end
  def src_file
    File.join(self.version_dir, self.src)
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
    @version = v
  end
end

H = Helper.new

def title(msg)
  puts "\n=== #{msg} ".ljust(80, '-')
end



desc "Report version information and exit"
task :version do
	puts "#{Helper::Project} #{H.version}"
end

RSpec::Core::RakeTask.new 'spec' do |t|
  t.pattern = './spec/*.rb'
end

spec = Gem::Specification.new do |s|
  s.name        = H.name
  s.version     = H.version
  s.author      = 'Macquarie Sharpless'
  s.email       = 'macquarie.sharpless@gmail.com'
  s.description = 'ARKWEB is a static website compiler'
  s.summary     = s.description
  s.homepage    = 'https://github.com/grimheart/arkweb'

  s.files        = Dir.glob("{bin,lib,templates}/**/*") + %w(LICENSE README.md freeze.yaml)
  s.bindir      = 'bin'
  s.executables  = ['ark']
  s.require_path = 'lib'
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

Rake::RDocTask.new do |rd|
  rd.main       = 'README.md'
  rd.rdoc_dir   = 'doc'
  rd.title      = "ARKWEB #{H.version}"
  rd.rdoc_files = Dir['bin/*'] + Dir['lib/*']
end

desc "Freeze version info"
task :freeze do
  freeze = {}
  freeze['version']  = H.version
  File.open('freeze.yaml', 'w') do |f|
    YAML.dump(freeze, f)
  end
end

desc "Cleanup freeze info"
task :melt do
  FileUtils.rm('freeze.yaml') if File.exist?('freeze.yaml')
end

desc "Build a gem"
task :buildgem => [:clobber, :freeze, :gem, :melt] do
end

desc "Generate a PKGBUILD for the latest version, to be used with makepkg"
task :pkgbuild => :buildgem do
  title "Generating PKGBUILD"
  FileUtils.rm_r('build/') if File.directory?('build/')
  FileUtils.mkdir('build/')
  @version = H.version
  FileUtils.cp("pkg/#{H.gem}",'build', :verbose => true)
  check = Digest::MD5.file("build/#{H.gem}").to_s
  @md5  = "md5sums=('#{check}')"
  File.open('PKGBUILD.erb', 'r') do |f|
    erb = ERB.new(f.read)
    pb = erb.result(binding)
    File.open('build/PKGBUILD', 'w') {|o| o.write(pb) }
  end
end

desc "Run makepkg, generating a .pkg file for use with pacman"
task :makepkg => :pkgbuild do
  title "MAKEPKG"
  Dir.chdir('build/')
  sh('makepkg -fc')
  H.return
end

desc "Generate a source tar suitable for upload to the AUR"
task :aur => :pkgbuild do
  title "TAURBALL"
  Dir.chdir('build/')
  sh('makepkg -f --source')
  H.return
end

desc "Scan generated PKGBUILD and .pkg. using namcap"
task :namcap => :makepkg do
  title "NAMCAP"
  Dir.chdir('build/')
  sh('namcap PKGBUILD')
  sh("namcap #{H.pkg}")
  H.return
end

desc "Perform full packaging task, producing a gem, a pacman package and AUR src tar."
task :pack => [:buildgem, :makepkg, :aur, :namcap] do
  title "Finishing package task. See #{H.version_dir}"
  FileUtils.rm_r(H.version_dir, :verbose => true) if File.directory?(H.version_dir)
  FileUtils.mkdir_p(H.version_dir, :verbose => true)
  FileUtils.cp(["build/#{H.pkg}", H.src, H.gem], H.version_dir, :verbose => true)
  H.return
  FileUtils.ln_s(H.pkg_file, H.pkg_link, :force => true, :verbose => true)
  FileUtils.ln_s(H.gem_file, H.gem_link, :force => true, :verbose => true)
  FileUtils.ln_s(H.src_file, H.src_link, :force => true, :verbose => true)
end

desc "Uninstall arkweb if installed"
task :uninstall do
  sh("pacman -Q #{H.pkg_name} && sudo pacman -Rdd #{H.pkg_name}")
end

desc "Install pacman package, according to the version env variable"
task :install do
  sh("sudo pacman -U #{H.pkg_file}")
end

desc "Upload pkg to a repository"
task :upload_pkg do
  # TODO
end

desc "Upload src to the AUR"
task :upload_src do
  # TODO
end

desc "Upload gem to rubygems.org"
task :upload_gem do
  # TODO
end

task :genhtml do
  # TODO regenerate reference HTML used in testing (using last version binary?)
end

