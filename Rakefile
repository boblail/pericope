require "bundler/gem_tasks"
require "rake/testtask"
require "pericope"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
  t.verbose = false
end

task :compile do
  data_path = File.expand_path(File.dirname(__FILE__) + "/data")
  output_path = File.expand_path(File.dirname(__FILE__) + "/lib/pericope")

  current_book_id = nil
  chapters = 0
  chapter_verse_counts = {}
  book_chapter_counts = [nil]

  path = "#{data_path}/chapter_verse_count.txt"
  File.open(path) do |file|
    file.each do |text|
      row = text.chomp.split("\t")
      id, verses = row[0].to_i, row[1].to_i
      book_id = Pericope.get_book(id)

      chapter_verse_counts[id] = verses

      unless current_book_id == book_id
        book_chapter_counts.push chapters if current_book_id
        current_book_id = book_id
      end

      chapters = Pericope.get_chapter(id)
    end
  end
  book_chapter_counts.push chapters


  book_names = []
  book_name_regexes = {}

  path = "#{data_path}/book_abbreviations.txt"
  File.open(path) do |file|
    file.each do |text|
      next if text.start_with?("#") # skip comments

      # the file contains tab-separated values.
      # the first value is the ordinal of the book, subsequent values
      # represent abbreviations and misspellings that should be recognized
      # as the aforementioned book.
      segments = text.chomp.split("\t")
      book_id = segments.shift.to_i
      book_names[book_id] = segments.shift
      book_name_regexes[book_id] = /\b(?:#{segments.join("|")})\b/i
    end
  end

  File.open(output_path + "/data.rb", "w") do |file|
    file.write <<-RUBY
class Pericope
  CHAPTER_VERSE_COUNTS = #{chapter_verse_counts.inspect}.freeze
  BOOK_CHAPTER_COUNTS = #{book_chapter_counts.inspect}.freeze
  BOOK_NAMES = #{book_names.inspect}.freeze
  BOOK_NAME_REGEXES = #{book_name_regexes.inspect}.freeze
end
    RUBY
  end


end
