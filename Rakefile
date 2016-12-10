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

  File.open(output_path + "/data.rb", "w") do |file|
    file.write <<-RUBY
class Pericope
  CHAPTER_VERSE_COUNTS = #{chapter_verse_counts.inspect}.freeze
  BOOK_CHAPTER_COUNTS = #{book_chapter_counts.inspect}.freeze
end
    RUBY
  end

end
