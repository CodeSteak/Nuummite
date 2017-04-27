require "benchmark"
require "../src/nuummite"

puts
puts
puts "      user     system      total        real"
puts

db = Nuummite.new("benchmark_db")

db.auto_garbage_collect_after_writes = nil
db.sync = false

puts "1000_000 small writes"
puts Benchmark.measure {
  1000_000.times do |i|
    db["#{i}"] = "I <3 DATA"
  end
}
puts

puts "1000_000 small deletes"
puts Benchmark.measure {
  1000_000.times do |i|
    db.delete "#{i}"
  end
}
puts

db.shutdown
sleep 0.01

puts "reopen after 2000_000 operations"
puts Benchmark.measure {
  db = Nuummite.new("benchmark_db")
}
puts

1000_000.times do |i|
  db["#{i}/lol"] = "I <3 DATA !!!!"
end

puts "garbage collect with 1000_000 entries"
puts Benchmark.measure {
  db.garbage_collect
}
puts

db.shutdown
clean("benchmark_db")

def clean(dir_name = "tmpdb")
  Dir.foreach(dir_name) do |filename|
    path = "#{dir_name}#{File::SEPARATOR}#{filename}"
    File.delete(path) if File.file?(path)
  end
  Dir.rmdir(dir_name)
end
