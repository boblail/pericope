# encoding: UTF-8

require "pericope/version"
require "pericope/data"

class Pericope
  attr_reader :book,
              :book_chapter_count,
              :book_name,
              :original_string,
              :ranges




  def initialize(arg)
    case arg
    when String
      attributes = Pericope.match_one(arg)
      raise "no pericope found in #{arg} (#{arg.class})" if attributes.nil?

      @original_string = attributes[:original_string]
      set_book attributes[:book]
      @ranges = attributes[:ranges]

    when Array
      arg = arg.map(&:to_i)
      set_book Pericope.get_book(arg.first)
      @ranges = Pericope.group_array_into_ranges(arg)

    when Range
      set_book Pericope.get_book(arg.begin)
      @ranges = [arg]

    else
      attributes = arg
      @original_string = attributes[:original_string]
      set_book attributes[:book]
      @ranges = attributes[:ranges]

    end
  end



  def self.book_has_chapters?(book)
    BOOK_CHAPTER_COUNTS[book] > 1
  end

  def book_has_chapters?
    book_chapter_count > 1
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



  def self.split(text, pattern=nil)
    puts "DEPRECATION NOTICE: split will no longer accept a 'pattern' argument in Pericope 0.7.0" if pattern
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

    segments = ___split_segments_by_pattern(segments, pattern) if pattern
    segments
  end

  def self.___split_segments_by_pattern(segments, pattern)
    segments2 = []
    segments.each do |segment|
      if segment.is_a? Pericope
        segments2 << segment
      else
        segments2.concat(segment.split(pattern))
      end
    end
    segments2
  end



  def self.extract(text)
    puts "DEPRECATION NOTICE: the 'extract' method will be removed in Pericope 0.7.0"
    segments = split(text)
    text = ""
    pericopes = []
    segments.each do |segment|
      if segment.is_a?(String)
        text << segment
      else
        pericopes << segment
      end
    end
    {:text => text, :pericopes => pericopes}
  end



  def self.sub(text)
    segments = split(text)
    segments.inject("") do |text, segment|
      if segment.is_a?(String)
        text << segment
      else
        text << "{{#{segment.to_a.join(" ")}}}"
      end
    end
  end



  def self.rsub(text)
    text.gsub(/\{\{(\d{7,8} ?)+\}\}/) do |match|
      ids = match[2...-2].split.collect(&:to_i)
      Pericope.new(ids).to_s
    end
  end



  def to_s(options={})
    "#{book_name} #{well_formatted_reference(options)}"
  end



  def report
    puts "DEPRECATION NOTICE: the 'report' method will be removed in Pericope 0.7.0"
    "  #{self.original_string} => #{self}"
  end



  def to_a
    # one range per chapter
    chapter_ranges = []
    ranges.each do |range|
      min_chapter = Pericope.get_chapter(range.begin)
      max_chapter = Pericope.get_chapter(range.end)
      if min_chapter == max_chapter
        chapter_ranges << range
      else
        chapter_ranges << Range.new(range.begin, Pericope.get_last_verse(book, min_chapter))
        for chapter in (min_chapter+1)...max_chapter
          chapter_ranges << Range.new(
            Pericope.get_first_verse(book, chapter),
            Pericope.get_last_verse(book, chapter))
        end
        chapter_ranges << Range.new(Pericope.get_first_verse(book, max_chapter), range.end)
      end
    end

    chapter_ranges.inject([]) {|array, range| array.concat(range.to_a)}
  end



  def well_formatted_reference(options={})
    recent_chapter = nil # e.g. in 12:1-8, remember that 12 is the chapter when we parse the 8
    recent_chapter = 1 unless book_has_chapters?

    verse_range_separator = options.fetch(:verse_range_separator, "–") # en-dash
    chapter_range_separator = options.fetch(:chapter_range_separator, "—") # em-dash
    verse_list_separator = options.fetch(:verse_list_separator, ", ")
    chapter_list_separator = options.fetch(:chapter_list_separator, "; ")
    always_print_verse_range = options.fetch(:always_print_verse_range, false)

    s = ""
    ranges.each_with_index do |range, i|
      min_chapter = Pericope.get_chapter(range.begin)
      min_verse = Pericope.get_verse(range.begin)
      max_chapter = Pericope.get_chapter(range.end)
      max_verse = Pericope.get_verse(range.end)

      if i > 0
        if recent_chapter == min_chapter
          s << verse_list_separator
        else
          s << chapter_list_separator
        end
      end

      if min_verse == 1 && max_verse >= Pericope.get_max_verse(book, max_chapter) && !always_print_verse_range
        s << min_chapter.to_s
        s << "#{chapter_range_separator}#{max_chapter}" if max_chapter > min_chapter
      else
        if recent_chapter == min_chapter
          s << min_verse.to_s
        else
          recent_chapter = min_chapter
          s << "#{min_chapter}:#{min_verse}"
        end

        if range.count > 1

          if min_chapter == max_chapter
            s << "#{verse_range_separator}#{max_verse}"
          else
            recent_chapter = max_chapter
            s << "#{chapter_range_separator}#{max_chapter}:#{max_verse}"
          end
        end
      end
    end

    s
  end



  def intersects?(pericope)
    return false unless pericope.is_a?(Pericope)
    return false unless (self.book == pericope.book)

    self.ranges.each do |self_range|
      pericope.ranges.each do |other_range|
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



  def set_book(value)
    @book = value || raise(ArgumentError, "must specify book")
    @book_name = Pericope::BOOK_NAMES[@book]
    @book_chapter_count = Pericope::BOOK_CHAPTER_COUNTS[@book]
  end



  def self.get_first_verse(book, chapter)
    get_id(book, chapter, 1)
  end

  def self.get_last_verse(book, chapter)
    get_id(book, chapter, get_max_verse(book, chapter))
  end

  def self.get_next_verse(id)
    id + 1
  end

  def self.get_start_of_next_chapter(id)
    book = get_book(id)
    chapter = get_chapter(id) + 1
    verse = 1
    get_id(book, chapter, verse)
  end

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

  def self.get_id(book, chapter, verse)
    book = to_valid_book(book)
    chapter = to_valid_chapter(book, chapter)
    verse = to_valid_verse(book, chapter, verse)

    (book * 1000000) + (chapter * 1000) + verse
  end

  def self.get_book(id)
    id / 1000000 # the book is everything left of the least significant 6 digits
  end

  def self.get_chapter(id)
    (id % 1000000) / 1000 # the chapter is the 3rd through 6th most significant digits
  end

  def self.get_verse(id)
    id % 1000 # the verse is the 3 least significant digits
  end



  def self.group_array_into_ranges(array)
    return [] if array.nil? or array.empty?

    array.flatten!
    array.compact!
    array.sort!

    ranges = []
    range_start = array.shift
    range_end = range_start
    while true
      next_value = array.shift
      break if next_value.nil?

      if (next_value == get_next_verse(range_end)) ||
         (next_value == get_start_of_next_chapter(range_end))
        range_end = next_value
      else
        ranges << (range_start..range_end)
        range_start = range_end = next_value
      end
    end
    ranges << (range_start..range_end)

    ranges
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
    reference = normalize_reference(reference)
    parse_ranges(book, reference.split(/[,;]/))
  end

  def self.normalize_reference(reference)
    reference = reference.to_s
    NORMALIZATIONS.each { |(regex, replacement)| reference.gsub!(regex, replacement) }
    reference
  end

  def self.parse_ranges(book, ranges)
    recent_chapter = nil # e.g. in 12:1-8, remember that 12 is the chapter when we parse the 8
    recent_chapter = 1 if !book_has_chapters?(book)
    ranges.map do |range|
      range = range.split('-') # parse the low end of a verse range and the high end separately
      range << range[0] if (range.length < 2) # treat 12:4 as 12:4-12:4
      lower_chapter_verse = range[0].split(':').map(&:to_i) # parse "3:28" to [3,28]
      upper_chapter_verse = range[1].split(':').map(&:to_i) # parse "3:28" to [3,28]

      # treat Mark 3-1 as Mark 3-3 and, eventually, Mark 3:1-35
      if (lower_chapter_verse.length == 1) &&
         (upper_chapter_verse.length == 1) &&
         (upper_chapter_verse[0] < lower_chapter_verse[0])
        upper_chapter_verse = lower_chapter_verse.dup
      end

      # make sure the low end of the range and the high end of the range
      # are composed of arrays with two appropriate values: [chapter, verse]
      chapter_range = false
      if lower_chapter_verse.length < 2
        if recent_chapter
          lower_chapter_verse.unshift recent_chapter # e.g. parsing 11 in 12:1-8,11 => remember that 12 is the chapter
        else
          lower_chapter_verse[0] = Pericope.to_valid_chapter(book, lower_chapter_verse[0])
          lower_chapter_verse << 1 # no verse specified; this is a range of chapters, start with verse 1
          chapter_range = true
        end
      else
        lower_chapter_verse[0] = Pericope.to_valid_chapter(book, lower_chapter_verse[0])
      end
      lower_chapter_verse[1] = Pericope.to_valid_verse(book, *lower_chapter_verse)

      if upper_chapter_verse.length < 2
        if chapter_range
          upper_chapter_verse[0] = Pericope.to_valid_chapter(book, upper_chapter_verse[0])
          upper_chapter_verse << Pericope.get_max_verse(book, upper_chapter_verse[0]) # this is a range of chapters, end with the last verse
        else
          upper_chapter_verse.unshift lower_chapter_verse[0] # e.g. parsing 8 in 12:1-8 => remember that 12 is the chapter
        end
      else
        upper_chapter_verse[0] = Pericope.to_valid_chapter(book, upper_chapter_verse[0])
      end
      upper_chapter_verse[1] = Pericope.to_valid_verse(book, *upper_chapter_verse)

      recent_chapter = upper_chapter_verse[0] # remember the last chapter

      Range.new(
        Pericope.get_id(book, *lower_chapter_verse),
        Pericope.get_id(book, *upper_chapter_verse))
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
