class Pericope
  class Range
    include Enumerable

    def initialize(first, last)
      @begin = first
      @end = last
    end

    attr_reader :begin
    attr_reader :end

    def ==(other)
      return true if equal? other

      other.kind_of?(Pericope::Range) and
        self.begin == other.begin and
        self.end == other.end
    end

    alias_method :eql?, :==

    def hash
      self.begin.hash ^ self.end.hash
    end

    def each
      return to_enum unless block_given?

      current = self.begin
      while current <= self.end
        yield current
        current = current.succ
      end
      self
    end

    def inspect
      "#{self.begin.to_id}..#{self.end.to_id}"
    end

  end
end
