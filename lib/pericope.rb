# encoding: UTF-8

require 'pericope/version'

class Pericope
  attr_reader :book,
              :book_chapter_count,
              :book_name,
              :original_string,
              :ranges
  
  
  
  def self.book_names
    load_chapter_verse_count_books! unless defined?(@book_names)
    @book_names
  end
  
  def self.book_name_regexes
    @book_name_regexes ||= book_abbreviations.
      map { |book_number, book_regex| [book_number, /\b#{book_regex}\b/] }
  end
  
  
  
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
      
    else
      attributes = arg
      @original_string = attributes[:original_string]
      set_book attributes[:book]
      @ranges = attributes[:ranges]
      
    end
  end
  
  
  
  def self.book_has_chapters?(book)
    book_chapter_counts[book - 1] > 1
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
  
  
  
  def to_s
    "#{book_name} #{self.well_formatted_reference}"
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
  
  
  
  def well_formatted_reference
    recent_chapter = nil # e.g. in 12:1-8, remember that 12 is the chapter when we parse the 8
    recent_chapter = 1 unless book_has_chapters?
    ranges.map do |range|
      min_chapter = Pericope.get_chapter(range.begin)
      min_verse = Pericope.get_verse(range.begin)
      max_chapter = Pericope.get_chapter(range.end)
      max_verse = Pericope.get_verse(range.end)
      s = ""
      
      if min_verse == 1 and max_verse >= Pericope.get_max_verse(book, max_chapter)
        s << min_chapter.to_s
        s << "-#{max_chapter}" if max_chapter > min_chapter
      else
        if recent_chapter == min_chapter
          s << min_verse.to_s
        else
          recent_chapter = min_chapter
          s << "#{min_chapter}:#{min_verse}"
        end
        
        if range.count > 1
          
          s << "-"
          if min_chapter == max_chapter
            s << max_verse.to_s
          else
            recent_chapter = max_chapter
            s << "#{max_chapter}:#{max_verse}"
          end
        end
      end
      
      s
    end.join(", ")
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
    chapter_verse_counts[id]
  end
  
  def self.get_max_chapter(book)
    book_chapter_counts[book - 1]
  end
  
  
  
private
  
  
  
  def set_book(value)
    @book = value || raise(ArgumentError, "must specify book")
    @book_name = Pericope.book_names[@book - 1]
    @book_chapter_count = Pericope.book_chapter_counts[@book - 1]
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
      
      book = recognize_book(match[1])
      next unless book
      
      ranges = parse_reference(book, match[2])
      next if ranges.empty?
      
      attributes = {
        :original_string => match.to_s,
        :book => book,
        :ranges => ranges
      }
      
      yield attributes, match
    end
  end
  
  def self.recognize_book(book)
    book = book.to_s.downcase
    book_name_regexes.each do |book_regex|
      return book_regex[0] if book =~ book_regex[1]
    end
    nil
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
  
  
  
  def self.load_chapter_verse_count_books!
    current_book_name = nil
    chapters = 0
    @book_names = []
    @chapter_verse_counts = {}
    @book_chapter_counts = []
    
    path = File.expand_path(File.dirname(__FILE__) + "/../data/chapter_verse_count.txt")
    File.open(path) do |file|
      file.each do |text|
        row = text.chomp.split("\t")
        id, verses, book_name = row[0].to_i, row[1].to_i, row[2]
        
        @chapter_verse_counts[id] = verses
        
        unless current_book_name == book_name
          if current_book_name
            @book_names.push current_book_name
            @book_chapter_counts.push chapters
          end
          current_book_name = book_name
        end
        
        chapters = get_chapter(id)
      end
    end
    
    @book_names.push current_book_name
    @book_chapter_counts.push chapters
  end
  
  
  
  def self.load_book_abbreviations!
    path = File.expand_path(File.dirname(__FILE__) + "/../data/book_abbreviations.txt")
    book_abbreviations = []
    File.open(path) do |file|
      file.each do |text|
        unless text.start_with?("#") # skip comments
          
          # the file contains tab-separated values.
          # the first value is the ordinal of the book, subsequent values
          # represent abbreviations and misspellings that should be recognized
          # as the aforementioned book.
          segments = text.chomp.split("\t")
          book_abbreviations << [segments.shift.to_i, "(?:#{segments.join("|")})"]
        end
      end
    end
    Hash[book_abbreviations]
  end
  
  
  
  def self.chapter_verse_counts
    load_chapter_verse_count_books! unless defined?(@chapter_verse_counts)
    @chapter_verse_counts
  end
  
  
  
  def self.book_abbreviations
    @book_abbreviations ||= load_book_abbreviations!
  end
  
  
  
  def self.book_chapter_counts
    load_chapter_verse_count_books! unless defined?(@book_chapter_counts)
    @book_chapter_counts
  end
  
  
  BOOK_PATTERN = /\b(?:(?:1|2|3|i+|first|second|third|1st|2nd|3rd) )?(?:\w+| of )\b/
  
  REFERENCE_PATTERN = '(?:\s*\d{1,3})(?:\s*[:\"\.]\s*\d{1,3}[ab]?(?:\s*[,;]\s*(?:\d{1,3}[:\"\.])?\s*\d{1,3}[ab]?)*)?(?:\s*[-–—]\s*(?:\d{1,3}\s*[:\"\.])?(?:\d{1,3}[ab]?)(?:\s*[,;]\s*(?:\d{1,3}\s*[:\"\.])?\s*\d{1,3}[ab]?)*)*'
  
  PERICOPE_PATTERN = /(#{BOOK_PATTERN})\.? (#{REFERENCE_PATTERN})/i
  
  NORMALIZATIONS = [
    [/(\d+)[".](\d+)/, '\1:\2'], # 12"5 and 12.5 -> 12:5
    [/[–—]/,           '-'],     # convert em dash and en dash to -
    [/[^0-9,:;\-–—]/,  '']       # remove everything but [0-9,;:-]
  ]
end
