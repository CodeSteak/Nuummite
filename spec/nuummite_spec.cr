require "./spec_helper"

def with_db(name)
  db = Nuummite.new("tmpdb", name)
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

  it "open empty file" do
    #create empty file
    folder = "tmpdb";
    Dir.mkdir(folder) unless Dir.exists?(folder)

    path = "#{folder}#{File::SEPARATOR}empty"

    file = File.new(path, "a")
    file.close()
    # and reopen it
    with_db("empty") do |db|
      db["a"] = "aaa"
      db["a"]?.should eq("aaa")
    end
  end

  it "open empty alt file" do
    #create empty alt file
    folder = "tmpdb";
    Dir.mkdir(folder) unless Dir.exists?(folder)

    path = "#{folder}#{File::SEPARATOR}empty2.1"

    file = File.new(path, "a")
    file.close()
    # and reopen it
    with_db("empty2") do |db|
      db["a"] = "aaa"
      db["a"]?.should eq("aaa")
    end
  end

  it "make new db and save state, do operations and garbage_collect" do
    with_db("one") do |db|
      db["a"] = "a✌a"
      db["b"] = "bbb"
      db["c"] = "ccc"
      db["d"] = "nope"
      db["e"] = "eee"

      db.delete("e")
      db["d"] = "ddd"

      db.garbage_collect
    end

    with_db("one") do |db|
      db["a"]?.should eq("a✌a")
      db["b"]?.should eq("bbb")
      db["c"]?.should eq("ccc")
      db["d"]?.should eq("ddd")
      db["e"]?.should eq(nil)
    end
  end

  it "each" do
    with_db("each") do |db|
      db["a"] = ">D"
      db["crystals/ruby"] = ""
      db["crystals/quartz"] = ""
      db["crystals/nuummite"] = ""

      i = 0
      db.each do
        i += 1
      end
      i.should eq(4)

      i = 0
      db.each("crystals/") do
        i += 1
      end
      i.should eq(3)

      db["a"]?.should eq(">D")
    end
  end

  it "garbage collect db" do
    with_db("two") do |db|
      1000.times do |i|
        db["key"] = "#{i}"
      end
      db.garbage_collect
    end
    file_size = File.size("tmpdb/two")
    (file_size < 100).should be_true
  end

  it "auto garbage collect db" do
    with_db("three") do |db|
      db.auto_garbage_collect_after_writes = 10000
      10001.times do |i|
        db["#{i}"] = "data"*5
        db.delete "#{i}"
      end
      sleep 0.01
      file_size = File.size("tmpdb/three")
      (file_size < 100).should be_true
    end
  end

  clean()
end

def clean(dir_name = "tmpdb")
  Dir.new(dir_name).each do |filename|
    path = "#{dir_name}#{File::SEPARATOR}#{filename}"
    File.delete(path) if File.file?(path)
  end
  Dir.rmdir(dir_name)
end
