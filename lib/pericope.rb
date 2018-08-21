require "pericope/version"
require "pericope/data"
require "pericope/parsing"

class Pericope
  extend Pericope::Parsing

  attr_reader :book, :original_string, :ranges


  def initialize(arg)
    case arg
    when String
      attributes = Pericope.match_one(arg)
      raise ArgumentError, "no pericope found in #{arg}" if attributes.nil?

      @original_string = attributes[:original_string]
      @book = attributes[:book]
      @ranges = attributes[:ranges]

    when Array
      @ranges = group_array_into_ranges(arg)
      @book = @ranges.first.begin.book

    else
      @original_string = arg[:original_string]
      @book = arg[:book]
      @ranges = arg[:ranges]

    end
    raise ArgumentError, "must specify book" unless @book
  end


  def book_has_chapters?
    book_chapter_count > 1
  end

  def book_name
    @book_name ||= Pericope::BOOK_NAMES[@book]
  end

  def book_chapter_count
    @book_chapter_count ||= Pericope::BOOK_CHAPTER_COUNTS[@book]
  end


  def to_s(options={})
    "#{book_name} #{well_formatted_reference(options)}"
  end

  def inspect
    "Pericope(#{to_s})"
  end


  def ==(other)
    other.is_a?(self.class) && [book, ranges] == [other.book, other.ranges]
  end

  def hash
    [book, ranges].hash
  end

  def <=>(other)
    to_a <=> other.to_a
  end

  def intersects?(other)
    return false unless other.is_a?(Pericope)
    return false unless book == other.book

    ranges.each do |self_range|
      other.ranges.each do |other_range|
        return true if (self_range.end >= other_range.begin) and (self_range.begin <= other_range.end)
      end
    end

    false
  end


  def to_a
    ranges.reduce([]) { |a, range| a.concat(range.to_a) }
  end


  class << self
    def book_has_chapters?(book)
      BOOK_CHAPTER_COUNTS[book] > 1
    end

    def get_max_verse(book, chapter)
      id = (book * 1000000) + (chapter * 1000)
      CHAPTER_VERSE_COUNTS[id]
    end

    def get_max_chapter(book)
      BOOK_CHAPTER_COUNTS[book]
    end
  end


private

  def well_formatted_reference(options={})
    verse_range_separator = options.fetch(:verse_range_separator, "–") # en-dash
    chapter_range_separator = options.fetch(:chapter_range_separator, "—") # em-dash
    verse_list_separator = options.fetch(:verse_list_separator, ", ")
    chapter_list_separator = options.fetch(:chapter_list_separator, "; ")
    always_print_verse_range = options.fetch(:always_print_verse_range, false)
    always_print_verse_range = true unless book_has_chapters?

    recent_chapter = nil # e.g. in 12:1-8, remember that 12 is the chapter when we parse the 8
    recent_chapter = 1 unless book_has_chapters?

    ranges.each_with_index.each_with_object("") do |(range, i), s|
      if i > 0
        if recent_chapter == range.begin.chapter
          s << verse_list_separator
        else
          s << chapter_list_separator
        end
      end

      if range.begin.verse == 1 && range.end.verse >= Pericope.get_max_verse(book, range.end.chapter) && !always_print_verse_range
        s << range.begin.chapter.to_s
        s << "#{chapter_range_separator}#{range.end.chapter}" if range.end.chapter > range.begin.chapter
      else
        s << range.begin.to_s(with_chapter: recent_chapter != range.begin.chapter)

        if range.begin != range.end
          if range.begin.chapter == range.end.chapter
            s << "#{verse_range_separator}#{range.end}"
          else
            s << "#{chapter_range_separator}#{range.end.to_s(with_chapter: true)}"
          end
        end

        recent_chapter = range.end.chapter
      end
    end
  end

  def group_array_into_ranges(verses)
    return [] if verses.nil? or verses.empty?

    verses = verses.flatten.compact.sort.map { |verse| Verse.parse(verse) }

    ranges = []
    range_begin = verses.shift
    range_end = range_begin
    while verse = verses.shift
      if verse == range_end.next
        range_end = verse
      else
        ranges << Range.new(range_begin, range_end)
        range_begin = range_end = verse
      end
    end

    ranges << Range.new(range_begin, range_end)
  end

end
