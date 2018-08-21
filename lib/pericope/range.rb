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

    def each(&block)
      return to_enum unless block_given?

      min_chapter = Pericope.get_chapter(self.begin)
      max_chapter = Pericope.get_chapter(self.end)

      unless min_chapter == max_chapter
        book = Pericope.get_book(self.begin)
        self.class.new(self.begin, Pericope.get_last_verse(book, min_chapter)).each(&block)
        for chapter in (min_chapter + 1)...max_chapter
          self.class.new(
            Pericope.get_first_verse(book, chapter),
            Pericope.get_last_verse(book, chapter)).each(&block)
        end
        self.class.new(Pericope.get_first_verse(book, max_chapter), self.end).each(&block)
        return
      end

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
