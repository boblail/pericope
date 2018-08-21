require "test_helper"

class VerseTest < Minitest::Test

  def setup
    Pericope.max_letter = "c"
  end


  context "Verse#==" do
    should "consider two verses to be inequal if they differ by partial" do
      examples = [ v("44001004"), v("44001004a"), v("44001004b") ]

      examples.combination(2).each do |a, b|
        refute a == b, "Expected #{a} != #{b}"
      end
    end
  end


  context "Verse#<" do
    should "sort by the _start_ of the verse" do
      assert v("44001004a") < v("44001004b"), "Expected Acts 1:4a to precede Acts 1:4b"
      assert v("44001004")  < v("44001004b"), "Expected Acts 1:4 to precede Acts 1:4b"

      refute v("44001004") < v("44001004a"), "Expected Acts 1:4 and Acts 1:4a to be sorted the same"
      refute v("44001004") > v("44001004a"), "Expected Acts 1:4 and Acts 1:4a to be sorted the same"
    end
  end


  context "Verse#next" do
    should "return the next verse" do
      assert_equal v(1003002), v(1003001).next
    end

    should "return the first verse of the next chapter for a verse that ends a chapter" do
      assert_equal v(1010001), v(1009029).next
    end

    should "return the next partial if the verse is a partial verse" do
      assert_equal v("1003001c"), v("1003001b").next
    end

    should "return the next whole verse if a partial verse has the last allowable letter" do
      assert_equal v(1003002), v("1003001c").next
    end
  end


private

  def v(arg)
    Pericope::Verse.parse(arg)
  end

end
