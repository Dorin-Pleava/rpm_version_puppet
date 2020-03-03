require "rpm_version_puppet"

describe RpmVersionPuppet::VersionRange do
  context "should fail if version cannot be parsed" do
    #FIXME
  end
  context "when creating new version range" do
    it "it includes specified version" do
      vr = RpmVersionPuppet::VersionRange.parse('1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.2')
      expect(vr.include?(v)).to eql(true)
    end
  end

  context "when creating new version range with equal operator" do
    it "it includes specified version" do
      vr = RpmVersionPuppet::VersionRange.parse('=1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.2')
      expect(vr.include?(v)).to eql(true)
    end

    it "it does not include other version" do
      vr = RpmVersionPuppet::VersionRange.parse('=1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.3')
      expect(vr.include?(v)).to eql(false)
    end
  end

  context "when creating new version range with greater or equal operator" do
    it "it includes greater version" do
      vr = RpmVersionPuppet::VersionRange.parse('>=1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.5')
      expect(vr.include?(v)).to eql(true)
    end

    it "it includes specified version" do
      vr = RpmVersionPuppet::VersionRange.parse('>=1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.2')
      expect(vr.include?(v)).to eql(true)
    end

    it "it does not include lower version" do
      vr = RpmVersionPuppet::VersionRange.parse('>=1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.1')
      expect(vr.include?(v)).to eql(false)
    end
  end

  context "when creating new version range with greater operator" do
    it "it includes greater version" do
      vr = RpmVersionPuppet::VersionRange.parse('>1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.5')
      expect(vr.include?(v)).to eql(true)
    end

    it "it does not include specified version" do
      vr = RpmVersionPuppet::VersionRange.parse('>1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.2')
      expect(vr.include?(v)).to eql(false)
    end

    it "it does not include lower version" do
      vr = RpmVersionPuppet::VersionRange.parse('>1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.1')
      expect(vr.include?(v)).to eql(false)
    end
  end

  context "when creating new version range with lower or equal operator" do
    it "it does not include greater version" do
      vr = RpmVersionPuppet::VersionRange.parse('<=1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.5')
      expect(vr.include?(v)).to eql(false)
    end

    it "it includes specified version" do
      vr = RpmVersionPuppet::VersionRange.parse('<=1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.2')
      expect(vr.include?(v)).to eql(true)
    end

    it "it includes lower version" do
      vr = RpmVersionPuppet::VersionRange.parse('<=1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.1')
      expect(vr.include?(v)).to eql(true)
    end
  end

  context "when creating new version range with lower operator" do
    it "it does not include greater version" do
      vr = RpmVersionPuppet::VersionRange.parse('<1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.5')
      expect(vr.include?(v)).to eql(false)
    end

    it "it does not include specified version" do
      vr = RpmVersionPuppet::VersionRange.parse('<1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.2')
      expect(vr.include?(v)).to eql(false)
    end

    it "it includes specified version" do
      vr = RpmVersionPuppet::VersionRange.parse('<1:20191210.1-0ubuntu0.19.04.2')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.1')
      expect(vr.include?(v)).to eql(true)
    end
  end
 
  context "when creating new version range with interval" do
    it "it does not include greater version" do
      vr = RpmVersionPuppet::VersionRange.parse('>1:20191210.1-0ubuntu0.19.04.2 <=1:20191210.1-0ubuntu0.19.05')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.05.1')
      expect(vr.include?(v)).to eql(false)
    end

    it "it includes specified max interval value" do
      vr = RpmVersionPuppet::VersionRange.parse('>1:20191210.1-0ubuntu0.19.04.2 <=1:20191210.1-0ubuntu0.19.05')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.05')
      expect(vr.include?(v)).to eql(true)
    end

    it "it includes in interval version" do
      vr = RpmVersionPuppet::VersionRange.parse('>1:20191210.1-0ubuntu0.19.04.2 <=1:20191210.1-0ubuntu0.19.05')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.10')
      expect(vr.include?(v)).to eql(true)
    end

    it "it does not include min interval value " do
      vr = RpmVersionPuppet::VersionRange.parse('>1:20191210.1-0ubuntu0.19.04.2 <=1:20191210.1-0ubuntu0.19.05')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.2')
      expect(vr.include?(v)).to eql(false)
    end

    it "it does not include lower value " do
      vr = RpmVersionPuppet::VersionRange.parse('>1:20191210.1-0ubuntu0.19.04.2 <=1:20191210.1-0ubuntu0.19.05')
      v = RpmVersionPuppet::Version.parse('1:20191210.1-0ubuntu0.19.04.1')
      expect(vr.include?(v)).to eql(false)
    end
  end
end
