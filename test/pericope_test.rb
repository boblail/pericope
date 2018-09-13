require "test_helper"

class PericopeTest < Minitest::Test

  def setup
    Pericope.max_letter = "d"
  end


  context "quickly recognizes Bible references:" do
    context "BOOK_PATTERN" do
      should "match valid books (including by abbreviations and common misspellings)" do
        tests = {
          "ii samuel" => "ii samuel",
          "1 cor." => "1 cor",
          "jas" => "jas",
          "song of songs" => "song of songs",
          "song of solomon" => "song of solomon",
          "first kings" => "first kings",
          "3rd jn" => "3rd jn",
          "phil" => "phil" }

        tests.each do |input, expected_match|
          assert_equal expected_match, input[Pericope::BOOK_PATTERN], "Expected Pericope to recognize \"#{input}\" as a potential book"
        end
      end
    end

    context "regexp" do
      should "match things that look like pericopes" do
        tests = [ "Romans 3:9" ]

        tests.each do |input|
          assert input[Pericope.regexp], "Expected Pericope to recognize \"#{input}\" as a potential pericope"
        end
      end

      should "not match things that do not look like pericopes" do
        tests = [
          "Hezekiah 4:3",   # Not a real book of the Bible
          "Psalm 1460003",  # `146` of `Psalm 146` is part of another word
          "Jude 4abacus"    # `4a` of `Jude 4a` is part of another word
        ]

        tests.each do |input|
          refute input[Pericope.regexp], "Expected Pericope to recognize that \"#{input}\" is not a potential pericope"
        end
      end
    end
  end



  context "knows various boundaries in the Bible:" do
    context "get_max_chapter" do
      should "return the last chapter of a given book" do
        tests = [
          [ 1,  50],  # Genesis has 50 chapters
          [19, 150],  # Psalms has 150 chapters
          [65,   1],  # Jude has only 1 chapter
          [66,  22] ] # Revelation has 22 chapters

        tests.each do |book, chapters|
          assert_equal chapters, Pericope.get_max_chapter(book)
        end
      end
    end

    context "get_max_verse" do
      should "return the last verse of a given chapter" do
        tests = [
          [ 1,   9,  29],    # Genesis 9 has 29 verses
          [ 1,  50,  26] ]   # Genesis 50 has 26 verses

        tests.each do |book, chapter, verses|
          assert_equal verses, Pericope.get_max_verse(book, chapter)
        end
      end
    end

    context "book_has_chapters?" do
      should "correctly identify books that don't have chapters" do
        assert Pericope.book_has_chapters?(1),  "Genesis has chapters"
        assert Pericope.book_has_chapters?(23), "Isaiah has chapters"
        refute Pericope.book_has_chapters?(57), "Philemon does not have chapters"
        refute Pericope.book_has_chapters?(65), "Jude does not have chapters"
      end
    end
  end



  context "identifies books of the Bible:" do
    context "it" do
      should "return an integer identifying the book of the Bible" do
        tests = {
          "Romans" => 45,  # Romans
          "mark"   => 41,  # Mark
          "ps"     => 19,  # Psalms
          "jas"    => 59,  # James
          "ex"     => 2 }  # Exodus

        tests.each do |input, book|
          assert_equal book, Pericope("#{input} 1").book, "Expected Pericope to be able to identify \"#{input}\" as book ##{book}"
        end
      end
    end
  end



  context "parses the chapter-and-verse notation identifying Bible references:" do
    context "parse_reference_fragment" do
      should "split chapter and verse" do
        assert_equal ref(chapter: 3, verse: 45), Pericope.parse_reference_fragment("3:45")
      end

      should "ignore default_chapter when the input contains both chapter and verse" do
        assert_equal ref(chapter: 3, verse: 45), Pericope.parse_reference_fragment("3:45", default_chapter: 11)
      end

      should "use default_chapter when the input contains only one number" do
        assert_equal ref(chapter: 11, verse: 45), Pericope.parse_reference_fragment("45", default_chapter: 11)
      end

      should "leave verse blank when the input contains only one number and default_chapter is nil" do
        assert_equal ref(chapter: 45), Pericope.parse_reference_fragment("45")
      end
    end

    context "parse_reference" do
      should "parse a range of verses" do
        assert_equal [r(19001001, 19008009)], Pericope.parse_reference(19, "1-8") # Psalm 1-8
      end

      should "parse a range of verses that spans a chapter" do
        assert_equal [r(43012001, 43013008)], Pericope.parse_reference(43, "12:1–13:8") # John 12:1–13:8
      end

      should "parse a single verse as a range of one" do
        assert_equal [r(60001001)], Pericope.parse_reference(60, "1:1") # 1 Peter 1:1
      end

      should "parse a chapter into a range of verses in that chapter" do
        assert_equal [r(1001001, 1001031)], Pericope.parse_reference(1, "1") # Genesis 1
      end

      should "parse multiple ranges into an array of ranges" do
        expected_ranges = [
          r(40003001),
          r(40003003),
          r(40003004, 40003005),
          r(40003007),
          r(40004019) ]

        tests = [
          "3:1,3,4-5,7; 4:19",
          "3:1, 3 ,4-5; 7,4:19"
        ]

        tests.each do |input|
          assert_equal expected_ranges, Pericope.parse_reference(40, input) # Matthew 3:1,3,4-5,7; 4:19
        end
      end

      should "allow various punctuation errors for chapter/verse pairing" do
        tests = ["1:4-9", "1\"4-9", "1.4-9", "1 :4-9", "1: 4-9"]

        tests.each do |input|
          assert_equal [r(28001004, 28001009)], Pericope.parse_reference(28, input)
        end
      end

      should "resolve partial-verses with \"a\" and \"b\"" do
        assert_equal [r("39002006b", "39002009a")], Pericope.parse_reference(39, "2:6b-9a")
        assert_equal [r("39002006b"), r("39002009a")], Pericope.parse_reference(39, "2:6b, 9a")
      end

      should "ignore \"a\" when a range starts with it" do
        assert_equal [r(39002006, 39002009)], Pericope.parse_reference(39, "2:6a-9")
      end

      should "allow a range to end with a \"b\" if Pericope.max_letter >= \"c\"" do
        assert_equal [r("39002006", "39002009b")], Pericope.parse_reference(39, "2:6-9b")
        Pericope.max_letter = "b"
        assert_equal [r(39002006, 39002009)], Pericope.parse_reference(39, "2:6-9b")
      end

      should "parse e.g. \"9:12a, c\"" do
        assert_equal [r("58009012a"), r("58009012c")], Pericope.parse_reference(58, "9:12a, c")
      end

      should "work correctly on books with no chapters" do
        assert_equal [r(65001008, 65001010)], Pericope.parse_reference(65, "8–10")
      end

      should "ignore chapter notation for chapterless books" do
        assert_equal [r(57001008, 57001010)], Pericope.parse_reference(57, "6:8–10")
      end

      should "coerce verses to the right range" do
        assert_equal [r(41001045)], Pericope.parse_reference(41, "1:452")
        assert_equal [r(41001001)], Pericope.parse_reference(41, "1:0")
      end

      should "coerce chapters to the right range" do
        assert_equal [r(43021001)], Pericope.parse_reference(43, "28:1")
        assert_equal [r(43001001)], Pericope.parse_reference(43, "0:1")
      end
    end
  end



  context "parses whole Bible references:" do
    context "parse_one" do
      should "work" do
        pericope = Pericope.parse_one("ps 1:1-6")
        assert_equal "Psalm", pericope.book_name
        assert_equal [r(19001001, 19001006)], pericope.ranges
      end

      should "work even when there is no space between the book name and reference" do
        pericope = Pericope.parse_one("ps1")
        assert_equal "Psalm", pericope.book_name
        assert_equal [r(19001001, 19001006)], pericope.ranges
      end

      should "return nil for an invalid reference" do
        assert_nil Pericope.parse_one("nope")
      end

      should "ignore text before and after a reference" do
        tests = {
          "This is some text about 1 Cor 1:1" => "1 Corinthians 1:1",
          "(Jas. 1:13, 20) "                  => "James 1:13, 20",
          "jn 21:14, "                        => "John 21:14",
          "zech 4:7, "                        => "Zechariah 4:7",
          "mt 12:13. "                        => "Matthew 12:13",
          "Luke 2---Maris "                   => "Luke 2",
          "Luke 3\"1---Aliquam "              => "Luke 3:1",
          "Psalm 146; antiphon v. 2"          => "Psalm 146",
          "(Acts 13:4-20a)"                   => "Acts 13:4–20a" }

        tests.each do |input, expected_pericope|
          assert_equal expected_pericope, Pericope.parse_one(input).to_s, "Expected to find \"#{expected_pericope}\" in \"#{input}\""
        end
      end
    end
  end



  context "formats Bible references:" do
    context "#to_s" do
      should "standardize book names" do
        tests = {
          "James 4"      => ["jas 4"],
          "2 Samuel 7"   => ["2 sam 7", "iisam 7", "second samuel 7", "2sa 7", "2 sam. 7"] }

        tests.each do |expected_result, inputs|
          inputs.each do |input|
            pericope = Pericope(input)
            assert_equal expected_result, pericope.to_s, "Expected Pericope to format #{pericope.original_string} as #{expected_result}; got #{pericope}"
          end
        end
      end

      should "standardize chapter-and-verse notation" do
        tests = {
          "James 4:7"                => ["jas 4:7", "james 4:7", "James 4.7", "jas 4 :7", "jas 4: 7"],
          "Mark 1:1b–17; 2:3–5, 17a" => ["mk 1:1b-17,2:3-5,17a"], }

        tests.each do |expected_result, inputs|
          inputs.each do |input|
            pericope = Pericope(input)
            assert_equal expected_result, pericope.to_s, "Expected Pericope to format #{pericope.original_string} as #{expected_result}; got #{pericope}"
          end
        end
      end


      should "not repeat a verse number when displaying two partials of the same verse" do
        assert_equal "John 21:24a, c", Pericope("John 21:24a, 21:24c").to_s
      end

      should "omit verses when describing the entire chapter of a book" do
        assert_equal "Psalm 1", Pericope("Psalm 1:1-6").to_s
      end

      should "not consider the whole chapter read if the range excludes part of the first verse" do
        assert_equal "Psalm 1:1b–6", Pericope("Psalm 1:1b–6").to_s
      end

      should "not consider the whole chapter read if the range excludes part of the last verse" do
        assert_equal "Psalm 1:1–6a", Pericope("Psalm 1:1–6a").to_s
      end

      should "never omit verses when describing all the verses in chapterless book" do
        assert_equal "Jude 1–25", Pericope("Jude 1–25").to_s
      end


      should "allow customizing :verse_range_separator" do
        assert_equal "John 1:1_7", Pericope.new("john 1:1-7").to_s(verse_range_separator: "_")
      end

      should "allow customizing :chapter_range_separator" do
        assert_equal "John 1_3", Pericope.new("john 1-3").to_s(chapter_range_separator: "_")
      end

      should "allow customizing :verse_list_separator" do
        assert_equal "John 1:1_3", Pericope.new("john 1:1, 3").to_s(verse_list_separator: "_")
      end

      should "allow customizing :chapter_list_separator" do
        assert_equal "John 1:1_3:1", Pericope.new("john 1:1, 3:1").to_s(chapter_list_separator: "_")
      end

      should "allow customizing :always_print_verse_range" do
        assert_equal "John 1", Pericope.new("john 1").to_s(always_print_verse_range: false)
        assert_equal "John 1:1–51", Pericope.new("john 1").to_s(always_print_verse_range: true)
      end
    end
  end



  context "picks pericopes out of a paragraph of text:" do
    context "split" do
      should "split text from pericopes" do
        text = "Paul, rom. 12:1-4, Romans 9:7b, 11, Election, Theology of Glory, Theology of the Cross, 1 Cor 15, Resurrection"
        expected_fragments = [
          "Paul, ",
          Pericope("Romans 12:1–4"),
          ", ",
          Pericope("Romans 9:7b, 11"),
          ", Election, Theology of Glory, Theology of the Cross, ",
          Pericope("1 Corinthians 15"),
          ", Resurrection"
        ]

        assert_equal expected_fragments, Pericope.split(text)
      end
    end
  end



  context "can compare two Pericope:" do
    context "intersects?" do
      should "say whether two pericopes share any verses" do
        tests = [
          ["exodus 12", "exodus 12:3-13", "exodus 12:5"], # basic intersection
          ["3 jn 4-8", "3 jn 7:1-7", "3 jn 5"],           # intersection in a book with no chapters
          ["matt 3:5-8", "matt 3:1-5"],                   # intersection on edge verses
          ["matt 3:5-8", "matt 3:8-15"] ]                 # intersection on edge verses

        tests.each do |references|
          pericopes = references.map { |reference| Pericope(reference) }
          pericopes.combination(2).each do |a, b|
            assert a.intersects?(b), "Expected #{a} to intersect #{b}"
          end
        end

        a = Pericope("mark 3-1")
        b = Pericope("mark 2:1")
        refute a.intersects?(b), "Expected #{a} NOT to intersect #{b}"
      end
    end

    context "it" do
      should "consider two pericopes to be equal if they identify the same verses" do
        a = Pericope("rom. 1:5-6")
        b = Pericope("Romans 1:5–6")
        assert_equal a, b, "Expected two pericopes that refer to the same verses to be equal"
      end
    end
  end



  context "converts itself to and from an array of verse IDs:" do
    setup do
      @tests = {
        "Genesis 1:1"       => %w{1001001},
        "John 20:19–23"     => %w{43020019 43020020 43020021 43020022 43020023},
        "Psalm 1"           => %w{19001001 19001002 19001003 19001004 19001005 19001006},
        "Psalm 122:6—124:2" => %w{19122006 19122007 19122008 19122009 19123001 19123002 19123003 19123004 19124001 19124002},

        "Romans 3:1–4a"     => %w{45003001 45003002 45003003 45003004a},
        "Romans 3:1–4b"     => %w{45003001 45003002 45003003 45003004a 45003004b},
        "Romans 3:1b–4"     => %w{45003001b 45003001c 45003001d 45003002 45003003 45003004},
        "Romans 3:1b, 2–4"  => %w{45003001b 45003002 45003003 45003004},
        "Luke 1:17a, d"     => %w{42001017a 42001017d} }
    end

    context "new" do
      should "accept an array of verses" do
        @tests.each do |expected_reference, verses|
          assert_equal expected_reference, Pericope.new(verses).to_s, "Given %w{#{verses.join(" ")}}"
        end
      end

      should "chain successive verses into ranges" do
        tests = [
          [%w{43020019 43020020 43020021 43020022 43020023}, [r(43020019, 43020023)]],                # John 20:19–23
          [%w{43020019 43020020 43020021 43020022a}, [r(43020019, "43020022a")]],                     # John 20:19–23a
          [%w{19122007 19122008 19122009 19123001 19123002}, [r(19122007, 19123002)]],                # Psalm 122:7—123:2
          [%w{19122007 19122008 19123001 19123002}, [r(19122007, 19122008), r(19123001, 19123002)]] ] # Psalm 122:7–8, 123:1–2

        tests.each do |(verses, ranges)|
          assert_equal ranges, Pericope.new(verses).ranges
        end
      end

      should "handle duplicated verses gracefully" do
        tests = [
          [%w{19150001 19150002 19150003 19150003 19150004 19150005 19150006}, [r(19150001, 19150006)]],
          [%w{19117001 19117002 19117002a}, [r(19117001, 19117002)]],

          # Duplicates of the last verse in a book are a special case because Pericope::Verse#next will return nil
          [%w{19150001 19150002 19150003 19150004 19150005 19150006 19150006}, [r(19150001, 19150006)]],
          [%w{19150001 19150002 19150003 19150004 19150005 19150006 19150006a}, [r(19150001, 19150006)]],
        ]

        tests.each do |(verses, expected_pericope)|
          assert_equal expected_pericope, Pericope.new(verses).ranges
        end
      end

      should "ignore invalid verses" do
        # Psalm 117:3 does not exist
        assert_equal [r(19117001, 19117002)], Pericope.new(%w{19117001 19117002 19117003}).ranges
      end
    end

    context "#to_a" do
      should "return an array of verses" do
        @tests.each do |reference, expected_verses|
          assert_equal expected_verses, Pericope(reference).to_a.map(&:to_id), "Given #{reference}"
        end
      end
    end
  end



private

  def Pericope(text)
    Pericope.parse_one(text)
  end

  def r(low, high = low)
    Pericope::Range.new(v(low), v(high))
  end

  def v(arg)
    Pericope::Verse.parse(arg)
  end

  def ref(chapter:, verse: nil)
    Pericope::Parsing::ReferenceFragment.new(chapter, verse)
  end

end



at_exit do
  require "benchmark"

  example = "Paul, rom. 12:1-4, Romans 9:7, 11, Election, Theology of Glory, Theology of the Cross, 1 Cor 15, Resurrection"

  bm = [100, 1000, 10000].map do |n|
    Benchmark.measure do
      n.times { Pericope.split(example) }
    end
  end

  $stdout.puts "", "PERFORMANCE", *bm, ""
end
