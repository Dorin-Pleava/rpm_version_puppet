require 'rpm_version_puppet'

module RpmVersionPuppet
  class VersionRange
    # Parses a version range string into a comparable {VersionRange} instance.
    #
    # Currently parsed version range string may take any of the following:
    # forms:
    #
    # * Regular Rpm Version strings
    #   * ex. `"1.0.0"`, `"1.2.3-pre"`
    # * Inequalities
    #   * ex. `"> 1.0.0"`, `"<3.2.0"`, `">=4.0.0"`
    # * Range Intersections (min is always first)
    #   * ex. `">1.0.0 <=2.3.0"`
    #
    # @param range_string [String] the version range string to parse
    # @return [VersionRange] a new {VersionRange} instance
    # @api public

    SIMPLE = '([<>=]|<=|>=)?(' + Version::REGEX_FULL + ')'.freeze
    SIMPLE_RX = /\A#{SIMPLE}\Z/.freeze

    RANGE_SPLIT = /\s+/.freeze

    def self.parse(range_string)
      simples = range_string.split(RANGE_SPLIT).map do |simple|
        match, operator, version = *simple.match(SIMPLE_RX)
        case operator
        when '>'
          GtRange.new(Version::parse(version))
        when '>='
          GtEqRange.new(Version::parse(version))
        when '<'
          LtRange.new(Version::parse(version))
        when '<='
          LtEqRange.new(Version::parse(version))
        when '='
          EqRange.new(Version::parse(version))
        else
          EqRange.new(Version::parse(version))
        end
      end
      simples.size == 1 ? simples[0] : MinMaxRange.new(simples[0], simples[1])
    end

    class MinMaxRange
      def initialize(min, max)
        @min = min
        @max = max
      end
      def include?(version)
        @min.include?(version) && @max.include?(version)
      end
    end

    class SimpleRange
      def initialize(version)
        @version = version
      end
    end

    class EqRange < SimpleRange
      def to_s
        "=#{@version}"
      end
      def include?(version)
        version == @version
      end
    end

    class GtRange  < SimpleRange
      def to_s
        ">#{@version}"
      end
      def include?(version)
        version > @version
      end
    end

    class GtEqRange  < SimpleRange
      def to_s
        ">=#{@version}"
      end
      def include?(version)
        version >= @version
      end
    end

    class LtRange  < SimpleRange
      def to_s
        "<#{@version}"
      end
      def include?(version)
        version < @version
      end
    end

    class LtEqRange  < SimpleRange
      def to_s
        "<=#{@version}"
      end
      def include?(version)
        version <= @version
      end
    end
  end
end
