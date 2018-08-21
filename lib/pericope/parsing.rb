require "pericope/range"
require "pericope/verse"

class Pericope
  module Parsing

    # Differs from Pericope.new in that it won't raise an exception
    # if text does not contain a pericope but will return nil instead.
    def parse_one(text)
      parse(text) do |pericope|
        return pericope
      end
      nil
    end

    def parse(text)
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

    def split(text)
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

    def match_one(text)
      match_all(text) do |attributes|
        return attributes
      end
      nil
    end

    def match_all(text)
      text.scan(Pericope.regexp) do
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

    def parse_reference(book, reference)
      parse_ranges(book, normalize_reference(reference).split(/[,;]/))
    end

    def normalize_reference(reference)
      normalizations.reduce(reference.to_s) { |reference, (regex, replacement)| reference.gsub(regex, replacement) }
    end

    def parse_ranges(book, ranges)
      default_chapter = nil
      default_chapter = 1 unless book_has_chapters?(book)
      default_verse = nil

      ranges.map do |range|
        range_begin_string, range_end_string = range.split("-")

        # treat 12:4 as 12:4-12:4
        range_end_string ||= range_begin_string

        range_begin = parse_reference_fragment(range_begin_string, default_chapter: default_chapter, default_verse: default_verse)

        # no verse specified; this is a range of chapters, start with verse 1
        chapter_range = false
        if range_begin.needs_verse?
          range_begin.verse = 1
          chapter_range = true
        end

        range_begin.chapter = to_valid_chapter(book, range_begin.chapter)
        range_begin.verse = to_valid_verse(book, range_begin.chapter, range_begin.verse)

        if range_begin_string == range_end_string && !chapter_range
          range_end = range_begin.dup
        else
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
        end

        # e.g. parsing 11 in 12:1-8,11 => remember that 12 is the chapter
        default_chapter = range_end.chapter

        # e.g. parsing c in 9:12a, c => remember that 12 is the verse
        default_verse = range_end.verse

        range = Range.new(range_begin.to_verse(book: book), range_end.to_verse(book: book))

        # an 'a' at the beginning of a range is redundant
        range.begin.letter = nil if range.begin.letter == "a" && range.end.to_i > range.begin.to_i

        # a 'c' at the end of a range is redundant
        range.end.letter = nil if range.end.letter == max_letter && range.end.to_i > range.begin.to_i

        range
      end
    end

    def parse_reference_fragment(input, default_chapter: nil, default_verse: nil)
      chapter, verse, letter = input.match(Pericope.fragment_regexp).captures
      chapter = default_chapter unless chapter
      chapter, verse = [verse, nil] unless chapter
      verse = default_verse unless verse
      letter = nil unless verse
      ReferenceFragment.new(chapter.to_i, verse&.to_i, letter)
    end

    def to_valid_chapter(book, chapter)
      coerce_to_range(chapter, 1..get_max_chapter(book))
    end

    def to_valid_verse(book, chapter, verse)
      coerce_to_range(verse, 1..get_max_verse(book, chapter))
    end

    def coerce_to_range(number, range)
      return range.begin if number < range.begin
      return range.end if number > range.end
      number
    end


    ReferenceFragment = Struct.new(:chapter, :verse, :letter) do
      def needs_verse?
        verse.nil?
      end

      def to_verse(book:)
        Verse.new(book, chapter, verse, letter)
      end
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

end
