require "test_helper"

class PericopeTest < Minitest::Test



  def test_get_max_verse
    assert_equal 29, Pericope.get_max_verse(1, 9)
    assert_equal 26, Pericope.get_max_verse(1, 50)
  end



  def test_parsing_a_pericope_of_just_chapters
    pericope = Pericope.new('ps 1-8')
    assert_equal 'Psalm', pericope.book_name
    assert_equal 150, pericope.book_chapter_count
    assert_equal true, pericope.book_has_chapters?
  end



  def test_instantiating_pericope_from_a_range
    assert_equal Pericope.new("Ezekiel 2:8—3:11").to_s, Pericope.new(26002008..26003011).to_s
  end



  def test_valid_book_references
    tests = {
      "ii samuel" => "ii samuel",
      "1 cor." => "1 cor",
      "jas" => "jas",
      "song of songs" => "song of songs",
      "song of solomon" => "song of solomon",
      "first kings" => "first kings",
      "3rd jn" => "3rd jn",
      "phil" => "phil"
    }

    tests.each do |input, expected_match|
      assert_equal expected_match, input[Pericope::BOOK_PATTERN]
    end
  end



  def test_PERICOPE_PATTERN
    assert_nil "Cross, 1" =~ Pericope::PERICOPE_PATTERN, "\"Cross, 1\" should not be matched as a pericope!"
  end



  def test_parsing_single_pericopes
    tests = {
      # test basic parsing
      ["gen 1", "gen. 1", "Genesis 1", "gen 1:1-999"] => [1001001..1001031],
      ["ex 12", "exodus 12", "ex 12:1-999"] => [2012001..2012051],
      ["jn 12:1-13:8"] => [43012001..43013008],
      ["ipet 1:1", "first peter 1:1", "1pete 1:1", "1 pet. 1.1"] => [60001001..60001001],
      ["ps 1-8"] => [19001001..19008009],
      ["ps1"] => [19001001..19001006],
      ["mt4:15"] => [40004015..40004015],

      # test that 'a' and 'b' parts of verses are ignored
      ["mal 2:6a-9b", "mal 2:6-9"] => [39002006..39002009],

      # test basic parsing for books with no chapters
      ["jude 8-10", "jude 6:8-10"] => [65001008..65001010],

      # test different punctuation, errors for range separators
      ["matt 3:1,3,4-5,7,4:19", "matt 3:1, 3, 4-5, 7; 4:19"] => [40003001..40003001, 40003003..40003003, 40003004..40003005, 40003007..40003007, 40004019..40004019],

      # test different punctuation, errors for chapter/verse pairing
      ["hos 1:4-9", "hos 1\"4-9", "hos 1.4-9", "hos 1 :4-9", "hos 1: 4-9"] => [28001004..28001009],

      # test verse coercion
      ["mk 1:452"] => [41001045..41001045],
      ["Genesis 15-55"] => [1015001..1050026],

      # test chapter coercion
      ["jn 28:1", "jn 125:1", "jn 21:1"] => [43021001..43021001],
      ["jn 1:1", "jn 0:1"] => [43001001..43001001]
    }

    tests.each do |references, ranges|
      for reference in references
        pericope = Pericope.new(reference)
        assert_equal ranges.length, pericope.ranges.length, "There should be only #{ranges.length} ranges for \"#{reference}\"."
        for i in 0...ranges.length
          assert_equal ranges[i], pericope.ranges[i], "Failure parsing \"#{reference}\": expected #{ranges[i]}, got #{pericope.ranges[i]}."
        end
      end
    end
  end



  def test_comparing_pericopes
    tests = [
      ["exodus 12", "exodus 12:3-13", "exodus 12:5"],    # basic intersection
      ["3 jn 4-8", "3 jn 7:1-7", "3 jn 5"],              # intersection in a book with no chapters
      ["matt 3:5-8", "matt 3:1-5"],                      # intersection on edge verses
      ["matt 3:5-8", "matt 3:8-15"]                      # intersection on edge verses
    ]

    tests.each do |test|
      pericopes = test.map {|reference| Pericope.new(reference)}
      for a in pericopes
        for b in pericopes
          assert a.intersects?(b),                        "Intersection failure: expected #{a} to intersect #{b}"
        end
      end
    end
  end



  def test_comparing_with_an_invalid_pericope
    assert_equal false, Pericope.new("mark 3-1").intersects?(Pericope.new("mark 2:1"))
  end



  def test_formatting_pericopes
    tests = {
      ["jas 4:7", "james 4:7", "James 4.7", "jas 4 :7", "jas 4: 7"] => "James 4:7",     # test basic formatting
      ["2 sam 7", "iisam 7", "second samuel 7", "2sa 7", "2 sam. 7"] => "2 Samuel 7",   # test chapter range formatting
      ["philemon 8-10", "philemon 6:8-10"] => "Philemon 8–10",                          # test book with no chapters
      ["phil 1:1-17,2:3-5,17"] => "Philippians 1:1–17; 2:3–5, 17",                      # test comma-separated ranges

      # omits verses when describing an entire chapter...
      ["Psalm 1:1-6"] => "Psalm 1",

      # ...except when the book has only a single chapter
      ["Jude 1–25"] => "Jude 1–25",

      # test the values embedded in the pericope extraction
      ["Psalm 37:3–7a, 23–24, 39–40"] => "Psalm 37:3–7, 23–24, 39–40",
      ["John 20:19–23"] => "John 20:19–23",
      ["ex 2-3"] => "Exodus 2—3",
      ["2 Peter 4.1 "] => "2 Peter 3:1", # nb: chapter coercion
      ["(Jas. 1:13, 20) "] => "James 1:13, 20",
      ["jn 21:14, "] => "John 21:14",
      ["zech 4:7, "] => "Zechariah 4:7",
      ["mt 12:13. "] => "Matthew 12:13",
      ["Luke 2---Maris "] => "Luke 2",
      ["Luke 3\"1---Aliquam "] => "Luke 3:1",
      ["(Acts 13:4-20)"] => "Acts 13:4–20"
    }

    tests.each do |references, expected_result|
      pericopes = references.map {|reference| Pericope.new(reference)}
      for pericope in pericopes
        assert_equal expected_result, pericope.to_s, "Formatting failure: expected #{pericope.original_string} to become #{expected_result}, not #{pericope.to_s}."
      end
    end
  end



  def test_verse_range_separator
    assert_equal "John 1:1_7", Pericope.new("john 1:1-7").to_s(verse_range_separator: "_")
  end

  def test_chapter_range_separator
    assert_equal "John 1_3", Pericope.new("john 1-3").to_s(chapter_range_separator: "_")
  end

  def test_verse_list_separator
    assert_equal "John 1:1_3", Pericope.new("john 1:1, 3").to_s(verse_list_separator: "_")
  end

  def test_chapter_list_separator
    assert_equal "John 1:1_3:1", Pericope.new("john 1:1, 3:1").to_s(chapter_list_separator: "_")
  end

  def test_always_print_verse_range
    assert_equal "John 1", Pericope.new("john 1").to_s(always_print_verse_range: false)
    assert_equal "John 1:1–51", Pericope.new("john 1").to_s(always_print_verse_range: true)
  end

  # TODO: fix Pericope.new("john 1, 3") # <-- not finding chapter 3



  def test_converting_pericopes_to_arrays
    tests = {
      ["gen 1:1"] => [1001001],
      ["ps 1"] => [19001001, 19001002, 19001003, 19001004, 19001005, 19001006],
      ["ps 122:6-124:2"] => [19122006, 19122007, 19122008, 19122009, 19123001, 19123002, 19123003, 19123004, 19124001, 19124002],
      ["Psalm 4-1"] => [19004001, 19004002, 19004003, 19004004, 19004005, 19004006, 19004007, 19004008]
    }

    tests.each do |references, expected_result|
      pericopes = references.map {|reference| Pericope.new(reference)}
      for pericope in pericopes
        assert_equal expected_result, pericope.to_a,      "Formatting failure: expected #{pericope.original_string} to include #{expected_result}, not #{pericope.to_a}."
      end
    end
  end



  def test_converting_arrays_to_pericopes
    tests = {
      "Genesis 1:1" => [1001001],
      "John 20:19–23" => [43020019, 43020020, 43020021, 43020022, 43020023],
      "Psalm 1" => [19001001, 19001002, 19001003, 19001004, 19001005, 19001006],
      "Psalm 122:6—124:2" => [19122006, 19122007, 19122008, 19122009, 19123001, 19123002, 19123003, 19123004, 19124001, 19124002]
    }

    tests.each do |expected_result, array|
      pericope = Pericope.new(array)
      assert_equal expected_result, pericope.to_s
    end
  end



  def test_splitting_text_with_pericopes
    text = "Paul, rom. 12:1-4, Romans 9:7, 11, Election, Theology of Glory, Theology of the Cross, 1 Cor 15, Resurrection"
    expected_keywords = [
      "Paul",
      "Romans 12:1–4",
      "Romans 9:7, 11",
      "Election",
      "Theology of Glory",
      "Theology of the Cross",
      "1 Corinthians 15",
      "Resurrection"]

    # Convert pericopes to strings.
    # Remove leading and trailing whitespace.
    # Remove segments that consisted only of whitespace.
    keywords = (Pericope.to_enum(:split, text).map { |arg|
      arg.is_a?(Pericope) ? arg.to_s : arg.split(",").map(&:strip).reject(&:empty?)
    }).flatten
    assert_equal expected_keywords, keywords
  end



  def test_pericope_extraction
    text =  "2 Peter 4.1 Lorem ipsum dolor sit amet, Mark consectetur adipiscing elit 7. 1-2 Donec aliquam erat luctus
            lacinia. Cras aliquet urna sed massa viverra eget ultricies risus sodales. Maecenas aliquet felis nec
            justo pharetra rutrum eget a risus. (Jas. 1:13, 20) Etiam tincidunt pellentesque cursus. Nulla est libero,
            bibendum sed elementum vitae, elementum vehicula quam. In bibendum massa sed quam convallis sed lacinia
            orci aliquet. Donec tempus sodales, jn 21:14, zech 4:7, mk 3-1, and mt 12:13. Vestibulum nec nibh dolor,
            vel hendrerit libero. Donec porta felis at lectus condimentum sollicitudin. Donec samuel magna in leo
            vestibulum aliquam. Suspendisse eget magna leo 3\"2-1, in rutrum metus. Pellentesque nec lectus imperdiet
            arcu venenatis placerat in quis diam. Luke 2---Mauris enim sapien, feugiat at vulputate ac, imperdiet sit
            amet tellus. Donec posuere nisi odio, et laoreet libero. Luke 3\"1---Aliquam iaculis, elit sed venenatis
            suscipit, tellus nibh sodales tortor, non lobortis neque sapien quis ante. Vivamus laoreet, mi eu imperdiet
            bibendum, purus orci iaculis mi, vel first kings mi nisi auctor mauris. Integer dapibus lacinia arcu, ac
            dignissim justo consectetur sit amet. (Acts 13:4-20)"
    expected_text = " Lorem ipsum dolor sit amet, Mark consectetur adipiscing elit 7. 1-2 Donec aliquam erat luctus
            lacinia. Cras aliquet urna sed massa viverra eget ultricies risus sodales. Maecenas aliquet felis nec
            justo pharetra rutrum eget a risus. () Etiam tincidunt pellentesque cursus. Nulla est libero,
            bibendum sed elementum vitae, elementum vehicula quam. In bibendum massa sed quam convallis sed lacinia
            orci aliquet. Donec tempus sodales, , , , and . Vestibulum nec nibh dolor,
            vel hendrerit libero. Donec porta felis at lectus condimentum sollicitudin. Donec samuel magna in leo
            vestibulum aliquam. Suspendisse eget magna leo 3\"2-1, in rutrum metus. Pellentesque nec lectus imperdiet
            arcu venenatis placerat in quis diam. ---Mauris enim sapien, feugiat at vulputate ac, imperdiet sit
            amet tellus. Donec posuere nisi odio, et laoreet libero. ---Aliquam iaculis, elit sed venenatis
            suscipit, tellus nibh sodales tortor, non lobortis neque sapien quis ante. Vivamus laoreet, mi eu imperdiet
            bibendum, purus orci iaculis mi, vel first kings mi nisi auctor mauris. Integer dapibus lacinia arcu, ac
            dignissim justo consectetur sit amet. ()"
    # trick questions:
    #   Mark            - no reference part
    #   elit 7. 1-2     - 'elit' is not a book of the Bible
    #   samuel          - no reference part
    #   leo 3"2-1       - 'leo' is not a book of the Bible
    #   first kings     - no reference part
    expected_results = [
      "2 Peter 3:1", # nb: chapter coercion
      "James 1:13, 20",
      "John 21:14",
      "Zechariah 4:7",
      "Mark 3", # the reference is mk 3-1. We can't make sense of the "-1" part, but we can of "mk 3"
      "Matthew 12:13",
      "Luke 2",
      "Luke 3:1",
      "Acts 13:4–20"
    ]

    actual_text = ""
    actual_results = []
    Pericope.split(text) do |text_or_pericope|
      if text_or_pericope.is_a?(Pericope)
        actual_results << text_or_pericope.to_s
      else
        actual_text << text_or_pericope
      end
    end

    assert_equal expected_results, actual_results
    assert_equal expected_text, actual_text
  end



  def test_pericope_substitution
    text =  "2 Peter 3:1–2 Lorem ipsum dolor sit amet"
    expected_text = "{{61003001 61003002}} Lorem ipsum dolor sit amet"
    actual_text = Pericope.sub(text)
    assert_equal expected_text, actual_text

    expected_text, text = text, expected_text
    actual_text = Pericope.rsub(text)
    assert_equal expected_text, actual_text
  end



  def test_pericope_extraction_2
    expecations = {
      "This is some text about 1 Cor 1:1" => "1 Corinthians 1:1"
    }
    expecations.each do |text, expectation|
      assert_equal expectation, Pericope.parse_one(text).to_s, "Expected to find #{expectation.inspect} in #{text.inspect}"
    end
  end



  def test_equality
    a = Pericope.new("rom. 1:5-6")
    b = Pericope.new("Romans 1:5–6")
    assert_equal a, b, "Expected two pericopes that refer to the same verses to be equal"
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
