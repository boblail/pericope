require "pericope/version"
require "pericope/data"
require "pericope/parsing"

class Pericope
  extend Pericope::Parsing
  include Enumerable

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


  def each
    return to_enum unless block_given?

    ranges.each do |range|
      range.each do |verse|
        yield verse
      end
    end

    self
  end


  class << self
    attr_reader :max_letter

    def max_letter=(value)
      unless @max_letter == value
        @max_letter = value.freeze
        @_letters = nil
        @_regexp = nil
        @_normalizations = nil
        @_letter_regexp = nil
        @_fragment_regexp = nil
      end
    end

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

    def regexp
      @_regexp ||= /#{book_pattern}\.?\s*(#{reference_pattern})/i
    end

    def normalizations
      @_normalizations ||= [
        [/(\d+)[".](\d+)/, '\1:\2'],        # 12"5 and 12.5 -> 12:5
        [/[–—]/,           '-'],            # convert em dash and en dash to -
        [/[^0-9,:;\-–—#{letters}]/,  ''] ]  # remove everything but recognized symbols
    end

    def letter_regexp
      @_letter_regexp ||= /[#{letters}]$/
    end

    def fragment_regexp
      @_fragment_regexp ||= /^(?:(?<chapter>\d{1,3}):)?(?<verse>\d{1,3})?(?<letter>[#{letters}])?$/
    end

  private

    def book_pattern
      BOOK_PATTERN.source.gsub(/[ \n]/, "")
    end

    def reference_pattern
      number = '\d{1,3}'
      verse = "#{number}[#{letters}]?"
      chapter_verse_separator = '\s*[:"\.]\s*'
      list_or_range_separator = '\s*[\-–—,;]\s*'
      chapter_and_verse = "(?:#{number + chapter_verse_separator})?" + verse + '\b'
      chapter_and_verse_or_letter = "(?:#{chapter_and_verse}|[#{letters}]\\b)"
      chapter_and_verse + "(?:#{list_or_range_separator + chapter_and_verse_or_letter})*"
    end

    def letters
      @_letters ||= ("a"..max_letter).to_a.join
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
    recent_verse = nil

    ranges.each_with_index.each_with_object("") do |(range, i), s|
      if i > 0
        if recent_chapter == range.begin.chapter
          s << verse_list_separator
        else
          s << chapter_list_separator
        end
      end

      last_verse = Pericope.get_max_verse(book, range.end.chapter)
      if !always_print_verse_range && range.begin.verse == 1 && range.begin.whole? && (range.end.verse > last_verse || range.end.whole? && range.end.verse == last_verse)
        s << range.begin.chapter.to_s
        s << "#{chapter_range_separator}#{range.end.chapter}" if range.end.chapter > range.begin.chapter
      else
        if range.begin.partial? && range.begin.verse == recent_verse
          s << range.begin.letter
        else
          s << range.begin.to_s(with_chapter: recent_chapter != range.begin.chapter)
        end

        if range.begin != range.end
          if range.begin.chapter == range.end.chapter
            s << "#{verse_range_separator}#{range.end}"
          else
            s << "#{chapter_range_separator}#{range.end.to_s(with_chapter: true)}"
          end
        end

        recent_chapter = range.end.chapter
        recent_verse = range.end.verse if range.end.partial?
      end
    end
  end

  def group_array_into_ranges(verses)
    return [] if verses.nil? or verses.empty?

    verses = verses.flatten.compact.sort.each_with_object([]) do |verse, verses|
      begin
        verses << Verse.parse(verse)
      rescue ArgumentError
        # skip invalid verses
      end
    end

    ranges = []
    range_begin = verses.shift
    range_end = range_begin
    while verse = verses.shift
      if verse > range_end.next
        ranges << Range.new(range_begin, range_end)
        range_begin = range_end = verse
      elsif verse > range_end
        range_end = verse
      end

      break if range_end.next.nil? # end of book
    end

    ranges << Range.new(range_begin, range_end)
  end

end

Pericope.max_letter = "d"
