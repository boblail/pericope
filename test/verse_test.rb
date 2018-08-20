require "test_helper"

class VerseTest < Minitest::Test


  context "Verse#next" do
    should "return the next verse" do
      assert_equal v(1003002), v(1003001).next
    end

    should "return the first verse of the next chapter for a verse that ends a chapter" do
      assert_equal v(1010001), v(1009029).next
    end
  end


private

  def v(arg)
    Pericope::Verse.parse(arg)
  end

end
