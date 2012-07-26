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
  end
  attr_reader :home
  def name
    File.basename(@home)
  end
  def return
    Dir.chdir(@home)
  end
end
Help = Helper.new


GitVersion = `git tag`.lines.select {|l| l[/^v\d\.\d$/] }.last.strip
GitSeries  = `git tag`.lines.select {|l| l[/^series-/] }.last.strip
GemVersion = "#{GitVersion[1..-1]}.0"
PkgVersion = "#{AW::Project['name'].downcase}-#{GemVersion}"
VersionDir = File.join(Help.home, 'v', GemVersion)

RSpec::Core::RakeTask.new 'spec' do |t|
  t.pattern = './spec/*.rb'
end

spec = Gem::Specification.new do |s|
  s.name = AW::Project['name'].downcase
  s.version = GemVersion
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
  rd.title      = "ARKWEB #{GemVersion} '#{AW::Project['codename']}'"
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
  puts "\n Cloning checkout version #{GitVersion} ".ljust(80, '=')
  Dir.chdir('/tmp')
  FileUtils.rm_r(Help.name) if File.directory?(Help.name)
  `git clone #{Help.home}`
  Dir.chdir(Help.name)
  `git checkout #{GitVersion}`
end

desc "Freeze version info"
task :freeze do
  pr = YAML.load_file('project.yaml')
  pr['version']  = GitVersion
  pr['codename'] = GitSeries
  File.open('freeze.yaml', 'w') do |f|
    YAML.dump(pr, f)
  end
end

desc "Clone a temporary work area, checkout the latest version, freeze version info and build the gem"
task :buildgem => [:checkout, :freeze, :gem] do
  puts "\n Building gem and copying to . ".ljust(80, '=')
  FileUtils.mv("pkg/#{AW::Project['name'].downcase}-#{GemVersion}.gem", '.')
end

desc "Generate a PKGBUILD for the latest version, to be used with makepkg"
task :pkgbuild do
  puts "\n Generating PKGBUILD ".ljust(80, '=')
  @version = GemVersion
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
  system("namcap ruby-#{PkgVersion}-1-any.pkg.tar.xz")
end

desc "Perform full packaging task, producing a gem, Arch Linux pkg and AUR src tar."
task :pack => [:buildgem, :makepkg, :aur, :namcap] do
  gem = "#{PkgVersion}.gem"
  pkg = "ruby-#{PkgVersion}-1-any.pkg.tar.xz"
  src = "ruby-#{PkgVersion}-1.src.tar.gz"
  FileUtils.rm_r(VersionDir) if File.directory?(VersionDir)
  FileUtils.mkdir_p(VersionDir)
  FileUtils.cp([pkg, src, gem], VersionDir)
  Help.return
end

