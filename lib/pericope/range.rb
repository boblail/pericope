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

      if self.begin == self.end
        yield self.begin
        return self
      end

      current = self.begin
      last_verse = self.end.whole
      while current < last_verse
        yield current
        current = current.succ
      end

      if self.end.partial?
        "a".upto(self.end.letter).each do |letter|
          yield Verse.new(self.end.book, self.end.chapter, self.end.verse, letter)
        end
      else
        yield self.end
      end

      self
    end

    def inspect
      "#{self.begin.to_id}..#{self.end.to_id}"
    end

  end
end
