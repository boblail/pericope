require "test_helper"

class PericopeTest < Minitest::Test


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

    context "PERICOPE_PATTERN" do
      should "match things that look like pericopes" do
        tests = [ "Romans 3:9" ]

        tests.each do |input|
          assert input[Pericope::PERICOPE_PATTERN], "Expected Pericope to recognize \"#{input}\" as a potential pericope"
        end
      end

      should "not match things that do not look like pericopes" do
        tests = [ "Cross 1", "Hezekiah 4:3" ]

        tests.each do |input|
          refute input[Pericope::PERICOPE_PATTERN], "Expected Pericope to recognize that \"#{input}\" is not a potential pericope"
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
    context "parse_reference" do
      should "parse a range of verses" do
        assert_equal [19001001..19008009], Pericope.parse_reference(19, "1-8") # Psalm 1-8
      end

      should "parse a range of verses that spans a chapter" do
        assert_equal [43012001..43013008], Pericope.parse_reference(43, "12:1–13:8") # John 12:1–13:8
      end

      should "parse a single verse as a range of one" do
        assert_equal [60001001..60001001], Pericope.parse_reference(60, "1:1") # 1 Peter 1:1
      end

      should "parse a chapter into a range of verses in that chapter" do
        assert_equal [1001001..1001031], Pericope.parse_reference(1, "1") # Genesis 1
      end

      should "parse multiple ranges into an array of ranges" do
        expected_ranges = [
          40003001..40003001,
          40003003..40003003,
          40003004..40003005,
          40003007..40003007,
          40004019..40004019 ]

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
          assert_equal [28001004..28001009], Pericope.parse_reference(28, input)
        end
      end

      should "ignore \"a\" and \"b\"" do
        assert_equal [39002006..39002009], Pericope.parse_reference(39, "2:6a-9b")
      end

      should "work correctly on books with no chapters" do
        assert_equal [65001008..65001010], Pericope.parse_reference(65, "8–10")
      end

      should "ignore chapter notation for chapterless books" do
        assert_equal [57001008..57001010], Pericope.parse_reference(57, "6:8–10")
      end

      should "coerce verses to the right range" do
        assert_equal [41001045..41001045], Pericope.parse_reference(41, "1:452")
        assert_equal [41001001..41001001], Pericope.parse_reference(41, "1:0")
      end

      should "coerce chapters to the right range" do
        assert_equal [43021001..43021001], Pericope.parse_reference(43, "28:1")
        assert_equal [43001001..43001001], Pericope.parse_reference(43, "0:1")
      end
    end
  end



  context "parses whole Bible references:" do
    context "parse_one" do
      should "work" do
        pericope = Pericope.parse_one("ps 1:1-6")
        assert_equal "Psalm", pericope.book_name
        assert_equal [19001001..19001006], pericope.ranges
      end

      should "work even when there is no space between the book name and reference" do
        pericope = Pericope.parse_one("ps1")
        assert_equal "Psalm", pericope.book_name
        assert_equal [19001001..19001006], pericope.ranges
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
          "(Acts 13:4-20)"                    => "Acts 13:4–20" }

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
          "James 4:7"              => ["jas 4:7", "james 4:7", "James 4.7", "jas 4 :7", "jas 4: 7"],
          "Mark 1:1–17; 2:3–5, 17" => ["mk 1:1-17,2:3-5,17"] }

        tests.each do |expected_result, inputs|
          inputs.each do |input|
            pericope = Pericope(input)
            assert_equal expected_result, pericope.to_s, "Expected Pericope to format #{pericope.original_string} as #{expected_result}; got #{pericope}"
          end
        end
      end


      should "omit verses when describing the entire chapter of a book" do
        assert_equal "Psalm 1", Pericope("Psalm 1:1-6").to_s
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
        text = "Paul, rom. 12:1-4, Romans 9:7, 11, Election, Theology of Glory, Theology of the Cross, 1 Cor 15, Resurrection"
        expected_fragments = [
          "Paul, ",
          Pericope("Romans 12:1–4"),
          ", ",
          Pericope("Romans 9:7, 11"),
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



  context "converts itself to and from an array of verse IDs" do
    setup do
      @tests = {
        "Genesis 1:1"       => [1001001],
        "John 20:19–23"     => [43020019, 43020020, 43020021, 43020022, 43020023],
        "Psalm 1"           => [19001001, 19001002, 19001003, 19001004, 19001005, 19001006],
        "Psalm 122:6—124:2" => [19122006, 19122007, 19122008, 19122009, 19123001, 19123002, 19123003, 19123004, 19124001, 19124002] }
    end

    context "new" do
      should "accept an array of verses" do
        @tests.each do |expected_reference, verses|
          assert_equal expected_reference, Pericope.new(verses).to_s
        end
      end
    end

    context "#to_a" do
      should "return an array of verses" do
        @tests.each do |reference, expected_verses|
          assert_equal expected_verses, Pericope(reference).to_a.map(&:to_i), "Expected #{reference} to map to these verses: #{expected_verses}"
        end
      end
    end
  end



private

  def Pericope(text)
    Pericope.parse_one(text)
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
