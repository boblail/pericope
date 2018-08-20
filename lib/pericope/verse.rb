class Pericope
  Verse = Struct.new(:book, :chapter, :verse) do
    include Comparable

    def initialize(book, chapter, verse)
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
      new(book, chapter, verse)
    end

    def <=>(other)
      to_a <=> other.to_a
    end

    def to_i
      book * 1000000 + chapter * 1000 + verse
    end
    alias :number :to_i

    def to_s(with_chapter: false)
      with_chapter ? "#{chapter}:#{verse}" : verse.to_s
    end

    def next
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
