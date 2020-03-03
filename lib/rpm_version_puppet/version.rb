# frozen_string_literal: true

require 'rpm_version_puppet'
require 'pry-byebug'

module RpmVersionPuppet
  class Error < StandardError; end
  class Version < Numeric
    include Comparable

      # Note: self:: is required here to keep these constants in the context of what will
  # eventually become this Puppet::Type::Package::ProviderRpm class.
  # The query format by which we identify installed packages
  self::NEVRA_FORMAT = %Q{%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\\n}
  self::NEVRA_REGEX  = %r{^'?(\S+) (\S+) (\S+) (\S+) (\S+)$}
  self::NEVRA_FIELDS = [:name, :epoch, :version, :release, :arch]
  self::MULTIVERSION_SEPARATOR = "; "

  ARCH_LIST = [
    'noarch',
    'i386',
    'i686',
    'ppc',
    'ppc64',
    'armv3l',
    'armv4b',
    'armv4l',
    'armv4tl',
    'armv5tel',
    'armv5tejl',
    'armv6l',
    'armv7l',
    'm68kmint',
    's390',
    's390x',
    'ia64',
    'x86_64',
    'sh3',
    'sh4',
  ]

  ARCH_REGEX = Regexp.new(ARCH_LIST.join('|\.'))

    class ValidationFailure < ArgumentError; end

    def self.parse(ver)
      match, epoch, upstream_version, rpm_revision = *ver.match(REGEX_FULL_RX)

      unless match
        raise ValidationFailure, "Unable to parse '#{ver}' as a rpm version identifier"
      end

      new(epoch.to_i, upstream_version, rpm_revision).freeze
    end

    # def self.match_digits(a)
    #   a.match(/^([0-9]+)/)
    # end

    # def self.match_non_letters(a)
    #   a.match(/^([\.\+-]+)/)
    # end

    # def self.match_tildes(a)
    #   a.match(/^(~+)/)
    # end

    # def self.match_letters(a)
    #   a.match(/^([A-Za-z]+)/)
    # end

    # parse a rpm "version" specification
    # this re-implements rpm's
    # rpmUtils.miscutils.stringToVersion() in ruby
    def self.rpm_parse_evr(s)
      ei = s.index(':')
      if ei
        e = s[0, ei]
        s = s[ei + 1, s.length]
      else
        e = nil
      end
      begin
        e = String(Integer(e))
      rescue StandardError
        # If there are non-digits in the epoch field, default to nil
        e = nil
      end
      ri = s.index('-')
      if ri
        v = s[0, ri]
        r = s[ri + 1, s.length]
        if arch = r.scan(ARCH_REGEX)[0]
          a = arch.delete('.')
          r.gsub!(ARCH_REGEX, '')
        end
      else
        v = s
        r = nil
      end
      { epoch: e, version: v, release: r, arch: a }
    end

    # This is an attempt at implementing RPM's
    # lib/rpmvercmp.c rpmvercmp(a, b) in Ruby.
    #
    # Some of the things in here look REALLY
    # UGLY and/or arbitrary. Our goal is to
    # match how RPM compares versions, quirks
    # and all.
    #
    # I've kept a lot of C-like string processing
    # in an effort to keep this as identical to RPM
    # as possible.
    #
    # returns 1 if str1 is newer than str2,
    #         0 if they are identical
    #        -1 if str1 is older than str2
    def self.rpmvercmp(str1, str2)
      return 0 if str1 == str2

      front_strip_re = /^[^A-Za-z0-9~]+/

      while !str1.empty? || !str2.empty?
        # trim anything that's in front_strip_re and != '~' off the beginning of each string
        str1 = str1.gsub(front_strip_re, '')
        str2 = str2.gsub(front_strip_re, '')

        # "handle the tilde separator, it sorts before everything else"
        if str1 =~ /^~/ && str2 =~ /^~/
          # if they both have ~, strip it
          str1 = str1[1..-1]
          str2 = str2[1..-1]
          next
        elsif str1 =~ /^~/
          return -1
        elsif str2 =~ /^~/
          return 1
        end

        break if str1.empty? || str2.empty?

        # "grab first completely alpha or completely numeric segment"
        isnum = false
        # if the first char of str1 is a digit, grab the chunk of continuous digits from each string
        if str1 =~ /^[0-9]+/
          if str1 =~ /^[0-9]+/
            segment1 = $LAST_MATCH_INFO.to_s
            str1 = $LAST_MATCH_INFO.post_match
          else
            segment1 = ''
          end
          if str2 =~ /^[0-9]+/
            segment2 = $LAST_MATCH_INFO.to_s
            str2 = $LAST_MATCH_INFO.post_match
          else
            segment2 = ''
          end
          isnum = true
        # else grab the chunk of continuous alphas from each string (which may be '')
        else
          if str1 =~ /^[A-Za-z]+/
            segment1 = $LAST_MATCH_INFO.to_s
            str1 = $LAST_MATCH_INFO.post_match
          else
            segment1 = ''
          end
          if str2 =~ /^[A-Za-z]+/
            segment2 = $LAST_MATCH_INFO.to_s
            str2 = $LAST_MATCH_INFO.post_match
          else
            segment2 = ''
          end
        end

        # if the segments we just grabbed from the strings are different types (i.e. one numeric one alpha),
        # where alpha also includes ''; "numeric segments are always newer than alpha segments"
        if segment2.empty?
          return 1 if isnum

          return -1
        end

        if isnum
          # "throw away any leading zeros - it's a number, right?"
          segment1 = segment1.gsub(/^0+/, '')
          segment2 = segment2.gsub(/^0+/, '')
          # "whichever number has more digits wins"
          return 1 if segment1.length > segment2.length
          return -1 if segment1.length < segment2.length
        end

        # "strcmp will return which one is greater - even if the two segments are alpha
        # or if they are numeric. don't return if they are equal because there might
        # be more segments to compare"
        rc = segment1 <=> segment2
        return rc if rc != 0
      end # end while loop

      # if we haven't returned anything yet, "whichever version still has characters left over wins"
      if str1.length > str2.length
        return 1
      elsif str1.length < str2.length
        return -1
      else
        return 0
      end
    end

    # comment
    def self.compare_rpm_versions(mine, yours)
      rpm_compareEVR(rpm_parse_evr(yours), rpm_parse_evr(mine))
    end

    # this method is a native implementation of the
    # compare_values function in rpm's python bindings,
    # found in python/header-py.c, as used by rpm.
    def self.compare_values(s1, s2)
      if s1.nil? && s2.nil?
        return 0
      elsif !s1.nil? && s2.nil?
        return 1
      elsif s1.nil? && !s2.nil?
        return -1
      end

      rpmvercmp(s1, s2)
    end

    # how rpm compares two package versions:
    # rpmUtils.miscutils.compareEVR(), which massages data types and then calls
    # rpm.labelCompare(), found in rpm.git/python/header-py.c, which
    # sets epoch to 0 if null, then compares epoch, then ver, then rel
    # using compare_values() and returns the first non-0 result, else 0.
    # This function combines the logic of compareEVR() and labelCompare().
    #
    # "yours" can be v, v-r, or e:v-r.
    # "mine" will always be at least v-r, can be e:v-r
    def self.rpm_compareEVR(yours, mine)

      # binding.pry
      # pass on to rpm labelCompare

      unless yours[:epoch].nil?
        rc = compare_values(yours[:epoch], mine[:epoch])
        return rc unless rc == 0
      end

      rc = compare_values(yours[:version], mine[:version])
      return rc unless rc == 0

      # here is our special case, PUP-1244.
      # if yours[:release] is nil (not specified by the user),
      # and comparisons up to here are equal, return equal. We need to
      # evaluate to whatever level of detail the user specified, so we
      # don't end up upgrading or *downgrading* when not intended.
      #
      # This should NOT be triggered if we're trying to ensure latest.
      return 0 if yours[:release].nil?

      rc = compare_values(yours[:release], mine[:release])

      rc
    end

    def initialize(epoch, upstream_version, rpm_revision)
      @epoch            = epoch
      @upstream_version = upstream_version
      @rpm_revision = rpm_revision
    end

    attr_reader :epoch, :upstream_version, :rpm_revision

    def to_s
      s = @upstream_version
      s = "#{@epoch}:" + s if @epoch != 0
      s += "-#{@rpm_revision}" if @rpm_revision
      s
    end
    alias inspect to_s

    def eql?(other)
      other.is_a?(Version) &&
        @epoch.eql?(other.epoch) &&
        @upstream_version.eql?(other.upstream_version) &&
        @rpm_revision.eql?(other.rpm_revision)
    end
    alias == eql?

    def <=>(other)
      return nil unless other.is_a?(Version)

      cmp = @epoch <=> other.epoch
      if cmp == 0
        cmp = compare_upstream_version(other)
        cmp = compare_rpm_revision(other) if cmp == 0
      end
      cmp
    end

    def compare_upstream_version(other)
      mine = @upstream_version
      yours = other.upstream_version
      Version.compare_rpm_versions(mine, yours)
    end

    def compare_rpm_revision(other)
      mine = @rpm_revision
      yours = other.rpm_revision
      Version.compare_rpm_versions(mine, yours)
    end

    # Version string matching regexes
    REGEX_EPOCH = '(?:([0-9]+):)?'
    # alphanumerics and the characters . + - ~ , starts with a digit, ~ only of rpm_revision is present
    REGEX_UPSTREAM_VERSION = '([\.\+~0-9a-zA-Z-]+?)'
    # alphanumerics and the characters + . ~
    REGEX_RPM_REVISION = '(?:-([\.\+~0-9a-zA-Z]*))?'

    REGEX_FULL    = REGEX_EPOCH + REGEX_UPSTREAM_VERSION + REGEX_RPM_REVISION.freeze
    REGEX_FULL_RX = /\A#{REGEX_FULL}\Z/.freeze
  end
end
