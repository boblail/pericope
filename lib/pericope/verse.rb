class Pericope
  Verse = Struct.new(:book, :chapter, :verse, :letter) do
    include Comparable

    def initialize(book, chapter, verse, letter=nil)
      super

      raise ArgumentError, "#{book} is not a valid book" if book < 1 || book > 66
      raise ArgumentError, "#{chapter} is not a valid chapter" if chapter < 1 || chapter > Pericope.get_max_chapter(book)
      raise ArgumentError, "#{verse} is not a valid verse" if verse < 1 || verse > Pericope.get_max_verse(book, chapter)
    end

    def self.parse(input)
      return nil unless input
      id = input.to_i
      book = id / 1000000 # the book is everything left of the least significant 6 digits
      chapter = (id % 1000000) / 1000 # the chapter is the 3rd through 6th most significant digits
      verse = id % 1000 # the verse is the 3 least significant digits
      letter = input[Pericope.letter_regexp] if input.is_a?(String)
      new(book, chapter, verse, letter)
    end

    def <=>(other)
      raise ArgumentError, "Comparison of Pericope::Verse with #{other.class} failed" unless other.is_a?(Pericope::Verse)
      [ book, chapter, verse, letter || "a" ] <=> [ other.book, other.chapter, other.verse, other.letter || "a" ]
    end

    def ==(other)
      to_a == other.to_a
    end

    def to_i
      book * 1000000 + chapter * 1000 + verse
    end
    alias :number :to_i

    def to_id
      "#{to_i}#{letter}"
    end

    def to_s(with_chapter: false)
      with_chapter ? "#{chapter}:#{verse}#{letter}" : "#{verse}#{letter}"
    end

    def partial?
      !letter.nil?
    end

    def whole?
      letter.nil?
    end

    def whole
      return self unless partial?
      self.class.new(book, chapter, verse)
    end

    def next
      if partial? && (next_letter = letter.succ) <= Pericope.max_letter
        return self.class.new(book, chapter, verse, next_letter)
      end

      next_verse = verse + 1
      if next_verse > Pericope.get_max_verse(book, chapter)
        next_chapter = chapter + 1
        return nil if next_chapter > Pericope.get_max_chapter(book)
        self.class.new(book, next_chapter, 1)
      else
        self.class.new(book, chapter, next_verse)
      end
    end
    alias :succ :next

  end
end
