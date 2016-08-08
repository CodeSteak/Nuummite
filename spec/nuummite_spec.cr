require "./spec_helper"

def with_db(name)
  db = Nuummite.new("tmpdb",name)
  yield db
  db.shutdown
end

describe Nuummite do

  it "make new db and save state, do operations" do
    with_db("one") do |db|
      db["a"] = "aaa"
      db["b"] = "bbb"
      db["c"] = "ccc"
      db["d"] = "nope"
      db["e"] = "eee"

      db.delete("e")
      db["d"] = "ddd"
    end

    with_db("one") do |db|
      db["a"]?.should eq("aaa")
      db["b"]?.should eq("bbb")
      db["c"]?.should eq("ccc")
      db["d"]?.should eq("ddd")
      db["e"]?.should eq(nil)
    end
  end

  it "make new db and save state, do operations and clean" do
    with_db("one") do |db|
      db["a"] = "a✌a"
      db["b"] = "bbb"
      db["c"] = "ccc"
      db["d"] = "nope"
      db["e"] = "eee"

      db.delete("e")
      db["d"] = "ddd"

      db.clean
    end

    with_db("one") do |db|
      db["a"]?.should eq("a✌a")
      db["b"]?.should eq("bbb")
      db["c"]?.should eq("ccc")
      db["d"]?.should eq("ddd")
      db["e"]?.should eq(nil)
    end
  end

  it "clean db" do
    with_db("two") do |db|
      1000.times do |i|
        db["key"] = "#{i}"
      end
      db.clean()
    end
    file_size = File.size("tmpdb/two")
    (file_size < 100).should be_true
  end

  it "auto clean db" do
    with_db("three") do |db|
      db.autoclean_after_writes = 10000
      10001.times do |i|
        db["#{i}"] = "data"*5
        db.delete "#{i}"
      end

      file_size = File.size("tmpdb/three")
      (file_size < 100).should be_true
    end
  end

  clean()
end

def clean(dir_name = "tmpdb")
  Dir.foreach(dir_name) do |filename|
    path = "#{dir_name}#{File::SEPARATOR}#{filename}"
    File.delete(path) if File.file?(path)
  end
  Dir.rmdir(dir_name)
end
