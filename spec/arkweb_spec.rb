require 'arkweb-3'

describe AW::Site do
  describe '#new' do

    it "should return a new Site instance" do
      s = AW::Site.new('test/site')
      s.should be_an_instance_of(AW::Site)
    end

    it "should fail to load a site with a missing header" do
      expect {
        AW::Site.new('test/site-missing-header')
      }.to raise_error(AW::BrokenSiteError)
    end

    it "should fail to load a site with a malformed header" do
      expect {
        AW::Site.new('test/site-missing-header')
      }.to raise_error(AW::BrokenSiteError)
    end

  end
end

describe AW::Site do
  describe '#make_path' do
    it "should translate AW::Site::Path to site-local paths" do
    end
  end
end

describe AW::Interface do
  describe '#init' do
    it "should initialize a new site given a nonexistant path" do
      FileUtils.rm_r('test/site-init', :force => true)
      AW::Interface.run('test/site-init')
      out = Dir['test/site-init/*'].map {|p| File.basename(p) }
      ref = Dir['skel/*'].map {|p| File.basename(p) }
      out.should == ref
      ref.each do |p|
        skel = File.join('skel', p)
        test = File.join('test/site-init', p)
        if File.file?(p)
          d1 = File.open(skel) {|f| f.read }
          d2 = File.open(test) {|f| f.read }
          d1.should == d2
        end
      end
      FileUtils.rm_r('test/site-init', :force => true)
    end
  end
end

