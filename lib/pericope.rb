# encoding: UTF-8

require 'yaml'
require 'pericope/version'

class Pericope
  attr_reader :book,
              :book_chapter_count,
              :book_name,
              :index,
              :original_string,
              :ranges
  
  
  def self.book_names
    @@book_names ||= ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job", "Psalm", "Proverbs", "Ecclesiastes", "Song of Songs", "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel",  "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians", "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter", "1 John ", "2 John", "3 John", "Jude", "Revelation"]
  end
  
  def self.book_name_regexes
    @@book_name_regexes ||= begin
      book_abbreviations.map do |book|
        [book, Regexp.new("\\b#{book[1]}\\b.? (#{ValidReference})", true)]
      end
    end
  end
  
  
  
  def initialize(string_or_array)
    case string_or_array
    when String, MatchData
      match = string_or_array.is_a?(String) ? Pericope.match_one(string_or_array) : string_or_array
      raise "no pericope found in #{string_or_array} (#{string_or_array.class})" if match.nil?
      
      @original_string = match.to_s
      @index = match.begin(0)
      set_book match.instance_variable_get('@book')
      @ranges = parse_reference(match[1])
      
    when Array
      set_book Pericope.get_book(string_or_array.first)
      @ranges = Pericope.group_array_into_ranges(string_or_array)
      
    else
      raise ArgumentError, "#{string_or_array.class} is not a recognized input for pericope"
    end
  end
  
  
  
  def book_has_chapters?
    (book_chapter_count > 1)
  end
  
  
  
  def self.parse_one(text)
    match = match_one(text)
    match ? Pericope.new(match) : nil
  end
  
  
  
  def self.parse(text, &block)
    pericopes = []
    match_all text do |match|
      pericope = Pericope.new(match)
      if block_given?
        yield pericope
      else
        pericopes << pericope
      end
    end
    block_given? ? text : pericopes
  end
  
  
  
  def self.split(text, pattern=nil)
    matches = match_all(text) # find every pericope in the text
    matches = matches.sort {|a,b| a.begin(0) <=> b.begin(0)} # put them in the order of their occurrence
    
    segments = []
    start = 0
    for match in matches
      pretext = text.slice(start...match.begin(0))
      segments.concat(pattern ? pretext.split(pattern).delete_if{|s| s.length==0} : [pretext]) if (pretext.length>0)
      segments << Pericope.new(match)
      start = match.end(0)
    end
    pretext = text.slice(start...text.length)
    segments.concat(pattern ? pretext.split(pattern).delete_if{|s| s.length==0} : [pretext]) if (pretext.length>0)
    
    segments
  end
  
  
  
  def self.extract(text)
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
    "  #{self.original_string} => #{self}"
  end
  
  
  
  def to_a
    # one range per chapter
    chapter_ranges = []
    for range in ranges
      min_chapter = Pericope.get_chapter(range.min)
      max_chapter = Pericope.get_chapter(range.max)
      if (min_chapter==max_chapter)
        chapter_ranges << range
      else
        chapter_ranges << Range.new(range.min, Pericope.get_last_verse(book, min_chapter))
        for chapter in (min_chapter+1)...max_chapter
          chapter_ranges << Range.new(
            Pericope.get_first_verse(book, chapter),
            Pericope.get_last_verse(book, chapter))
        end
        chapter_ranges << Range.new(Pericope.get_first_verse(book, max_chapter), range.max)
      end
    end
    
    chapter_ranges.inject([]) {|array, range| array.concat(range.to_a)}
  end
  
  
  
  def well_formatted_reference
    recent_chapter = nil # e.g. in 12:1-8, remember that 12 is the chapter when we parse the 8
    recent_chapter = 1 if !self.book_has_chapters?
    ranges.map do |range|
      min_chapter = Pericope.get_chapter(range.min)
      min_verse = Pericope.get_verse(range.min)
      max_chapter = Pericope.get_chapter(range.max)
      max_verse = Pericope.get_verse(range.max)
      s = ""
      
      if (min_verse==1) and (max_verse>=Pericope.get_max_verse(book, max_chapter))
        s << min_chapter.to_s
        if max_chapter > min_chapter
          s << "-#{max_chapter}"
        end
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
    for self_range in self.ranges
      for other_range in pericope.ranges
        return true if (self_range.max >= other_range.min) and (self_range.min <= other_range.max)
      end
    end
    return false
  end
  
  
  
  def self.get_max_verse(book, chapter)
    id = (book * 1000000) + (chapter * 1000)
    chapter_verse_counts[id]
  end
  
  
  
private
  
  
  
  def set_book(value)
    @book = value || raise(ArgumentError, "must specify book")
    @book_name = Pericope.book_names[@book-1]
    @book_chapter_count = Pericope.book_chapter_counts[@book-1]    
  end
  
  
  
  def parse_reference(reference)
    reference = normalize_reference(reference)
    (reference.nil? || reference.empty?) ? [] : parse_ranges(reference.split(/[,;]/).delete_if{|s| s.length==0})
  end
  
  def normalize_reference(reference)
    [ [%r{[".]},':'],                     # 12"5 and 12.5 -> 12:5
      [%r{:\s*\(},':'],                   # replace any ( after a : with a : only
      [%r{(\(|\))},','],                  # replace any remaining () with a , 
      [%r{(–|—)},'-'],                    # convert em dash and en dash to -
      [%r{[^0-9,:;\-–—]},'']              # remove everything but [0-9,;:-]
    ].each { |pattern, replacement| reference.gsub!(pattern, replacement) }
    reference
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
  
  def self.get_id(book, chapter, verse) #, constrain_verse=false)
    book = book.to_i
    book = 1 if book < 1
    book = 66 if book > 66
    
    max = book_chapter_counts[book-1]
    chapter = chapter.to_i
    chapter = 1 if chapter < 1
    chapter = max if chapter > max
    
    # max = constrain_verse ? get_max_verse(book, chapter) : 999
    # max = 999
    max = get_max_verse(book, chapter)
    verse = verse.to_i
    verse = 1 if verse < 1
    verse = max if verse > max
    
    return (book * 1000000) + (chapter * 1000) + verse;
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
    match_all(text) do |match|
      return match
    end
    nil
  end
  
  def self.get_unmatched_ending(match)
    i      = 0
    str    = match.to_s
    stack  = []

    str.each_char { |c| 
      if c == '('
        stack << c
      elsif c == ')'
        if stack.size() > 0
          stack.pop()
        else
          return str[i..str.length-1] 
        end
      end
      i = i + 1
    }

    return ""
  end


  # matches all valid Bible references in the supplied string
  # ! will not necessarily return references in order !
  def self.match_all(text, &block)
    matches = []
    unmatched = text
    
    for book_regex in book_name_regexes
      rx = book_regex[1]
      while (match = unmatched.match rx) # find all occurrences of pericopes in this book

        # calculate the unnecessary parens at the end of the statement
        unmatchedEnding = Pericope.get_unmatched_ending(match)
        length = match.end(0) - match.begin(0) - unmatchedEnding.length
        lengthFromBegin = match.end(0) - unmatchedEnding.length

        # recalculate the matchdata based on the shortened expression
        if unmatchedEnding.length > 0 
          match = unmatched[0..lengthFromBegin - 1].match(rx)
        end

        # after matching "2 Peter" don't match "Peter" again as "1 Peter"
        # but keep the same number of characters in the string so indices work
        unmatched = match.pre_match + ("*" * length) + match.post_match
        match.instance_variable_set('@book', book_regex[0][0])
        if block_given?
          yield match
        else
          matches << match
        end
      end
    end
    block_given? ? text : matches
  end
  
  def parse_ranges(ranges)
    return if ranges == nil

    recent_chapter = nil # e.g. in 12:1-8, remember that 12 is the chapter when we parse the 8
    recent_chapter = 1 if !self.book_has_chapters?
    ranges.map do |range|

      range = range.split('-') # parse the low end of a verse range and the high end separately

      range << range[0] if (range.length < 2) # treat 12:4 as 12:4-12:4
      lower_chapter_verse = range[0].split(':').map {|n| n.to_i} # parse "3:28" to [3,28]
      upper_chapter_verse = range[1].split(':').map {|n| n.to_i} # parse "3:28" to [3,28]
      
      # make sure the low end of the range and the high end of the range
      # are composed of arrays with two appropriate values: [chapter, verse]
      chapter_range = false
      if lower_chapter_verse.length < 2
        if recent_chapter        
          lower_chapter_verse.unshift recent_chapter # e.g. parsing 11 in 12:1-8,11 => remember that 12 is the chapter
        else
          lower_chapter_verse << 1 # no verse specified; this is a range of chapters, start with verse 1
          chapter_range = true
        end
      end
      if upper_chapter_verse.length < 2
        if chapter_range
          upper_chapter_verse << Pericope.get_max_verse(book, upper_chapter_verse[0]) # this is a range of chapters, end with the last verse
        else
          upper_chapter_verse.unshift lower_chapter_verse[0] # e.g. parsing 8 in 12:1-8 => remember that 12 is the chapter
        end
      end
      recent_chapter = upper_chapter_verse[0] # remember the last chapter
      
      Range.new(
        Pericope.get_id(book, lower_chapter_verse[0], lower_chapter_verse[1]),
        Pericope.get_id(book, upper_chapter_verse[0], upper_chapter_verse[1]))

    end
  end
  
  
  
  def self.load_chapter_verse_counts
    path = File.expand_path(File.dirname(__FILE__) + "/../data/chapter_verse_count.yml")
    File.open(path) do |file|
      return YAML.load(file)
    end
  end
  
  
  
  def self.load_book_abbreviations
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
    book_abbreviations
  end
  
  
  
  def self.chapter_verse_counts
    @chapter_verse_counts ||= load_chapter_verse_counts
  end
  
  
  
  def self.book_abbreviations
    @@book_abbreviations ||= load_book_abbreviations
  end
  
  
  
  def self.book_chapter_counts
    @@book_chapter_counts ||= [
    # Chapters    Book Name        Book Number
      50,       # Genesis          1
      40,       # Exodus           2
      27,       # Leviticus        3
      36,       # Numbers          4
      34,       # Deuteronomy      5
      24,       # Joshua           6
      21,       # Judges           7
      4,        # Ruth             8
      31,       # 1 Samuel         9
      24,       # 2 Samuel        10
      22,       # 1 Kings         11
      25,       # 2 Kings         12
      29,       # 1 Chronicles    13
      36,       # 2 Chronicles    14
      10,       # Ezra            15
      13,       # Nehemiah        16
      10,       # Esther          17
      42,       # Job             18
      150,      # Psalm           19
      31,       # Proverbs        20
      12,       # Ecclesiastes    21
      8,        # Song of Songs   22
      66,       # Isaiah          23
      52,       # Jeremiah        24
      5,        # Lamentations    25
      48,       # Ezekiel         26
      12,       # Daniel          27
      14,       # Hosea           28
      3,        # Joel            29
      9,        # Amos            30
      1,        # Obadiah         31
      4,        # Jonah           32
      7,        # Micah           33
      3,        # Nahum           34
      3,        # Habakkuk        35
      3,        # Zephaniah       36
      2,        # Haggai          37
      14,       # Zechariah       38
      4,        # Malachi         39
      28,       # Matthew         40
      16,       # Mark            41
      24,       # Luke            42
      21,       # John            43
      28,       # Acts            44
      16,       # Romans          45
      16,       # 1 Corinthians   46
      13,       # 2 Corinthians   47
      6,        # Galatians       48
      6,        # Ephesians       49
      4,        # Philippians     50
      4,        # Colossians      51
      5,        # 1 Thessalonians 52
      3,        # 2 Thessalonians 53
      6,        # 1 Timothy       54
      4,        # 2 Timothy       55
      3,        # Titus           56
      1,        # Philemon        57
      13,       # Hebrews         58
      5,        # James           59
      5,        # 1 Peter         60
      3,        # 2 Peter         61
      5,        # 1 John          62
      1,        # 2 John          63
      1,        # 3 John          64
      1,        # Jude            65
      22]       # Revelation      66
  end
  
  ValidReference = begin
    #note: this regular expression will include "optional" verses enclosed in parentheses by default                 
    reference = '(\(?(\s*\d{1,3})(\s*[:\"\.]\s*\(?\s*\d{1,3}(a|b)?(\s*\))?(\s*(,|;| )\s*(\d{1,3}[:\"\.])?\s*\(?\s*\(?\s*\d{1,3}(a|b)?(\s*\))?)*)?(\s*(-|–|—)\s*(\s*\(?\s*\d{1,3}\s*[:\"\.])?(\d{1,3}(a|b)?)(\s*\))?(\s*(,|;| )\s*\(?\s*(\d{1,3}\s*[:\"\.])?\s*\(?\d{1,3}(a|b)?(\s*\))?)*)*)'
  end
  
  
  
end
