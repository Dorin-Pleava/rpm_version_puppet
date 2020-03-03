require 'rpm_version_puppet'

module RpmVersionPuppet
class Error < StandardError; end
  class Version < Numeric
    include Comparable

    class ValidationFailure < ArgumentError; end

    def self.parse(ver)
      match, epoch, upstream_version, rpm_revision = *ver.match(REGEX_FULL_RX)

      raise ValidationFailure, "Unable to parse '#{ver}' as a rpm version identifier" unless match

      new(epoch.to_i, upstream_version, rpm_revision).freeze
    end

    def self.match_digits(a)
      a.match(/^([0-9]+)/)
    end

    def self.match_non_letters(a)
      a.match(/^([\.\+-]+)/)
    end

    def self.match_tildes(a)
      a.match(/^(~+)/)
    end

    def self.match_letters(a)
      a.match(/^([A-Za-z]+)/)
    end

    def self.compare_rpm_versions(mine, yours)
      #   First the initial part of each string consisting entirely of non-digit characters is determined.
      # These two parts (one of which may be empty) are compared lexically. If a difference is found it is
      # returned. The lexical comparison is a comparison of ASCII values modified so that all the letters
      # sort earlier than all the non-letters and so that a tilde sorts before anything, even the end of a
      # part. For example, the following parts are in sorted order from earliest to latest: ~~, ~~a, ~, the
      # empty part, a.
      #
      #   Then the initial part of the remainder of each string which consists entirely of digit characters
      # is determined. The numerical values of these two parts are compared, and any difference found is
      # returned as the result of the comparison. For these purposes an empty string (which can only occur
      # at the end of one or both version strings being compared) counts as zero.
      #
      #   These two steps (comparing and removing initial non-digit strings and initial digit strings) are
      # repeated until a difference is found or both strings are exhausted.

      mine_index = 0
      yours_index = 0
      cmp = 0
      mine = "" unless mine
      yours = "" unless yours
      while mine_index < mine.length && yours_index < yours.length && cmp == 0
        #handle ~
        mymatch, mytilde = *Version.match_tildes(mine.slice(mine_index..-1))
        mytilde = "" unless mytilde

        yoursmatch, yourstilde = *Version.match_tildes(yours.slice(yours_index..-1))
        yourstilde = "" unless yourstilde

        cmp = -1 * (mytilde.length <=> yourstilde.length)
        mine_index += mytilde.length
        yours_index += yourstilde.length

        if cmp == 0 # handle letters

          mymatch, myletters = *Version.match_letters(mine.slice(mine_index..-1))
          myletters = "" unless myletters

          yoursmatch, yoursletters = *Version.match_letters(yours.slice(yours_index..-1))
          yoursletters = "" unless yoursletters

          cmp = myletters <=> yoursletters
          mine_index += myletters.length
          yours_index += yoursletters.length

          if cmp == 0 # handle nonletters except tilde
            mymatch, mynon_letters = *Version.match_non_letters(mine.slice(mine_index..-1))
            mynon_letters = "" unless mynon_letters

            yoursmatch, yoursnon_letters = *Version.match_non_letters(yours.slice(yours_index..-1))
            yoursnon_letters = "" unless yoursnon_letters

            cmp = mynon_letters <=> yoursnon_letters
            mine_index += mynon_letters.length
            yours_index += yoursnon_letters.length

            if cmp == 0 # handle digits
              mymatch, mydigits = *Version.match_digits(mine.slice(mine_index..-1))
              mydigits = "" unless mydigits

              yoursmatch, yoursdigits = *Version.match_digits(yours.slice(yours_index..-1))
              yoursdigits = "" unless yoursdigits

              cmp = mydigits.to_i <=> yoursdigits.to_i
              mine_index += mydigits.length
              yours_index += yoursdigits.length
            end
          end
        end
      end
      if cmp == 0
        if mine_index < mine.length && Version.match_tildes(mine[mine_index])
          cmp = -1
        elsif yours_index < yours.length && Version.match_tildes(yours[yours_index])
          cmp = 1
        elsif
          cmp = mine.length <=> yours.length
        end
      end
      cmp
    end

    def initialize(epoch, upstream_version, rpm_revision)
      @epoch            = epoch
      @upstream_version = upstream_version
      @rpm_revision  = rpm_revision
    end

    attr_reader :epoch, :upstream_version, :rpm_revision

    def to_s
      s = @upstream_version
      s = "#{@epoch}:" + s if @epoch != 0
      s = s + "-#{@rpm_revision}" if @rpm_revision
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
        if cmp == 0
          cmp = compare_rpm_revision(other)
        end
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
    REGEX_EPOCH   = '(?:([0-9]+):)?'
    # alphanumerics and the characters . + - ~ , starts with a digit, ~ only of rpm_revision is present
    REGEX_UPSTREAM_VERSION = '([\.\+~0-9a-zA-Z-]+?)'
    #alphanumerics and the characters + . ~
    REGEX_DEBIAN_REVISION = '(?:-([\.\+~0-9a-zA-Z]*))?'

    REGEX_FULL    = REGEX_EPOCH + REGEX_UPSTREAM_VERSION + REGEX_DEBIAN_REVISION.freeze
    REGEX_FULL_RX = /\A#{REGEX_FULL}\Z/.freeze
  end

end
