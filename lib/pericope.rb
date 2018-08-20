require "pericope/version"
require "pericope/data"
require "pericope/range"
require "pericope/verse"

class Pericope
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



  def self.book_has_chapters?(book)
    BOOK_CHAPTER_COUNTS[book] > 1
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



  # Differs from Pericope.new in that it won't raise an exception
  # if text does not contain a pericope but will return nil instead.
  def self.parse_one(text)
    parse(text) do |pericope|
      return pericope
    end
    nil
  end



  def self.parse(text)
    pericopes = []
    match_all(text) do |attributes|
      pericope = Pericope.new(attributes)
      if block_given?
        yield pericope
      else
        pericopes << pericope
      end
    end
    block_given? ? text : pericopes
  end



  def self.split(text)
    segments = []
    start = 0

    match_all(text) do |attributes, match|

      pretext = text.slice(start...match.begin(0))
      if pretext.length > 0
        segments << pretext
        yield pretext if block_given?
      end

      pericope = Pericope.new(attributes)
      segments << pericope
      yield pericope if block_given?

      start = match.end(0)
    end

    pretext = text.slice(start...text.length)
    if pretext.length > 0
      segments << pretext
      yield pretext if block_given?
    end

    segments
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



  def to_a
    ranges.reduce([]) { |a, range| a.concat(range.to_a) }
  end



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



  def self.get_max_verse(book, chapter)
    id = (book * 1000000) + (chapter * 1000)
    CHAPTER_VERSE_COUNTS[id]
  end

  def self.get_max_chapter(book)
    BOOK_CHAPTER_COUNTS[book]
  end



private



  def self.to_valid_book(book)
    coerce_to_range(book, 1..66)
  end

  def self.to_valid_chapter(book, chapter)
    coerce_to_range(chapter, 1..get_max_chapter(book))
  end

  def self.to_valid_verse(book, chapter, verse)
    coerce_to_range(verse, 1..get_max_verse(book, chapter))
  end

  def self.coerce_to_range(number, range)
    return range.begin if number < range.begin
    return range.end if number > range.end
    number
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



  # matches the first valid Bible reference in the supplied string
  def self.match_one(text)
    match_all(text) do |attributes|
      return attributes
    end
    nil
  end



  # matches all valid Bible references in the supplied string
  def self.match_all(text)
    text.scan(Pericope::PERICOPE_PATTERN) do
      match = Regexp.last_match
      book = BOOK_IDS[match.captures.find_index(&:itself)]

      ranges = parse_reference(book, match[67])
      next if ranges.empty?

      attributes = {
        :original_string => match.to_s,
        :book => book,
        :ranges => ranges
      }

      yield attributes, match
    end
  end

  def self.parse_reference(book, reference)
    parse_ranges(book, normalize_reference(reference).split(/[,;]/))
  end

  def self.normalize_reference(reference)
    NORMALIZATIONS.reduce(reference.to_s) { |reference, (regex, replacement)| reference.gsub(regex, replacement) }
  end

  def self.parse_ranges(book, ranges)
    default_chapter = nil
    default_chapter = 1 unless book_has_chapters?(book)

    ranges.map do |range|
      range_begin_string, range_end_string = range.split("-")

      # treat 12:4 as 12:4-12:4
      range_end_string ||= range_begin_string

      range_begin = parse_reference_fragment(range_begin_string, default_chapter: default_chapter)

      # no verse specified; this is a range of chapters, start with verse 1
      chapter_range = false
      if range_begin.needs_verse?
        range_begin.verse = 1
        chapter_range = true
      end

      range_begin.chapter = to_valid_chapter(book, range_begin.chapter)
      range_begin.verse = to_valid_verse(book, range_begin.chapter, range_begin.verse)

      range_end = parse_reference_fragment(range_end_string, default_chapter: (range_begin.chapter unless chapter_range))
      range_end.chapter = to_valid_chapter(book, range_end.chapter)

      # treat Mark 3-1 as Mark 3-3 and, eventually, Mark 3:1-35
      range_end.chapter = range_begin.chapter if range_end.chapter < range_begin.chapter

      # this is a range of chapters, end with the last verse
      if range_end.needs_verse?
        range_end.verse = get_max_verse(book, range_end.chapter)
      else
        range_end.verse = to_valid_verse(book, range_end.chapter, range_end.verse)
      end

      # e.g. parsing 11 in 12:1-8,11 => remember that 12 is the chapter
      default_chapter = range_end.chapter

      Range.new(range_begin.to_verse(book: book), range_end.to_verse(book: book))
    end
  end

  def self.parse_reference_fragment(input, default_chapter: nil)
    chapter, verse = input.split(":")
    chapter, verse = [default_chapter, chapter] if default_chapter && !verse
    ReferenceFragment.new(chapter.to_i, verse&.to_i)
  end



  ReferenceFragment = Struct.new(:chapter, :verse) do
    def needs_verse?
      verse.nil?
    end

    def to_verse(book:)
      Verse.new(book, chapter, verse)
    end
  end



  BOOK_PATTERN = %r{\b(?:
      (?:(?:3|iii|third|3rd)\s*(?:
        (john|joh|jon|jhn|jh|jo|jn)
      ))|
      (?:(?:2|ii|second|2nd)\s*(?:
        (samuels|samuel|sam|sa|sm)|
        (kings|king|kngs|kgs|kg|k)|
        (chronicles|chronicle|chron|chrn|chr)|
        (john|joh|jon|jhn|jh|jo|jn)|
        (corinthians?|cor?|corint?h?|corth)|
        (thessalonians?|thes{1,}|the?s?)|
        (timothy|tim|tm|ti)|
        (peter|pete|pet|ptr|pe|pt|pr)
      ))|
      (?:(?:1|i|first|1st)\s*(?:
        (samuels|samuel|sam|sa|sm)|
        (kings|king|kngs|kgs|kg|k)|
        (chronicles|chronicle|chron|chrn|chr)|
        (john|joh|jon|jhn|jh|jo|jn)|
        (corinthians?|cor?|corint?h?|corth)|
        (thessalonians?|thes{1,}|the?s?)|
        (timothy|tim|tm|ti)|
        (peter|pete|pet|ptr|pe|pt|pr)
      ))|
      (genesis|gen|gn|ge)|
      (exodus|exod|exo|exd|ex)|
      (leviticus|lev|levi|le|lv)|
      (numbers|number|numb|num|nmb|nu|nm)|
      (deuteronomy|deut|deu|dt)|
      (joshua|josh|jsh|jos)|
      (judges|jdgs|judg|jdg)|
      (ruth|rut|rth|ru)|
      (isaiah|isa|is|ia|isai|isah)|
      (ezra|ezr)|
      (nehemiah|neh|ne)|
      (esther|esth|est|es)|
      (job|jb)|
      (psalms|psalm|pslms|pslm|psm|psa|ps)|
      (proverbs|proverb|prov|prv|prvb|prvbs|pv)|
      (ecclesiastes|eccles|eccl|ecc|ecl)|
      ((?:the\s?)?song\s?of\s?solomon|(?:the\s?)?song\s?of\s?songs|sn?gs?|songs?|so?s|sol?|son|s\s?of\s?\ss)|
      (jeremiah?|jer?|jr|jere)|
      (lamentations?|lam?|lm)|
      (ezekiel|ezek|eze|ezk)|
      (daniel|dan|dn|dl|da)|
      (hosea|hos|ho|hs)|
      (joel|jl)|
      (amos|amo|ams|am)|
      (obadiah|obadia|obad|oba|obd|ob)|
      (jonah|jon)|
      (micah|mica|mic|mi)|
      (nahum|nah|nahu|na)|
      (habakk?uk|habk?)|
      (zephaniah?|ze?ph?)|
      (haggai|ha?gg?)|
      (zechariah?|ze?ch?)|
      (malachi|mal)|
      (matthew|matt|mat|ma|mt)|
      (mark|mrk|mk)|
      (luke|luk|lk|lu)|
      (john|joh|jon|jhn|jh|jo|jn)|
      (acts|act|ac)|
      (romans|roman|roms|rom|rms|ro|rm)|
      (galatians|galatian|galat|gala|gal|ga)|
      (ephesians?|eph?|ephe?s?)|
      (philippians?|phi?l|php|phi|philipp?)|
      (colossi?ans?|col?)|
      (titus|tit|ti)|
      (philemon|phl?mn?|philem?)|
      (hebrews|hebrew|heb)|
      (james|jam|jas|jm|js|ja)|
      (jude)|
      (revelations|revelation|revel|rev|rv|re)
  )}ix.freeze

  # The order books of the Bible are matched
  BOOK_IDS = [ 64, 10, 12, 14, 63, 47, 53, 55, 61, 9, 11, 13, 62, 46, 52, 54, 60, 1, 2, 3, 4, 5, 6,  7, 8, 23, 15, 16, 17, 18, 19, 20, 21, 22, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 48, 49, 50, 51, 56, 57, 58, 59, 65, 66 ].freeze

  BOOK_NAMES = [nil, "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job", "Psalm", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John", "Jude", "Revelation"].freeze

  REFERENCE_PATTERN = '(?:\s*\d{1,3})(?:\s*[:\"\.]\s*\d{1,3}[ab]?(?:\s*[,;]\s*(?:\d{1,3}[:\"\.])?\s*\d{1,3}[ab]?)*)?(?:\s*[-–—]\s*(?:\d{1,3}\s*[:\"\.])?(?:\d{1,3}[ab]?)(?:\s*[,;]\s*(?:\d{1,3}\s*[:\"\.])?\s*\d{1,3}[ab]?)*)*'

  PERICOPE_PATTERN = /#{BOOK_PATTERN.source.gsub(/[ \n]/, "")}\.?(#{REFERENCE_PATTERN})/i

  NORMALIZATIONS = [
    [/(\d+)[".](\d+)/, '\1:\2'], # 12"5 and 12.5 -> 12:5
    [/[–—]/,           '-'],     # convert em dash and en dash to -
    [/[^0-9,:;\-–—]/,  '']       # remove everything but [0-9,;:-]
  ]
end
