require "io"

class Nuummite
  VERSION = 1

  property auto_garbage_collect_after_writes : Int32? = 10_000_000
  property sync : Bool

  @log : File
  @kv : Hash(String, String)

  enum Opcode : UInt8
    RENAME = 3
    REMOVE = 2
    WRITE  = 1
  end

  def initialize(folder : String, @filename = "db.nuummite", @sync = true)
    @need_gc = false
    @log, @kv = open_folder(folder, @filename)
    @running = true
    spawn do
      manage_locks
    end
    garbage_collect if @need_gc
  end

  private def open_folder(folder, filename) : {File, Hash(String, String)}
    Dir.mkdir(folder) unless Dir.exists?(folder)

    path = "#{folder}#{File::SEPARATOR}#{filename}"
    alt_path = "#{folder}#{File::SEPARATOR}#{filename}.1"

    new_file = false

    kv = if File.exists?(path)
           read_file_to_kv path
         elsif File.exists?(alt_path)
           File.rename(alt_path, path)
           read_file_to_kv path
         else
           new_file = true
           Hash(String, String).new
         end

    file = File.new(path, "a")
    if new_file
      file.write_byte(VERSION.to_u8)
    end
    {file, kv}
  end

  @writes = 0
  private def check_autogc
    if autogc = @auto_garbage_collect_after_writes
      @writes += 1
      if @writes > autogc
        @writes = 0
        spawn do
          garbage_collect
        end
      end
    end
  end

  def shutdown
    save do
      @running = false
      @log.flush
    end
  end

  def delete(key)
    save do
      log_remove(key)
      @kv.delete(key)
    end
  ensure
    check_autogc
  end

  def []=(key, value)
    save do
      log_write(key, value)
      @kv[key] = value
    end
  ensure
    check_autogc
  end

  def [](key)
    @kv[key]
  end

  def []?(key)
    @kv[key]?
  end

  def each(starts_with : String = "")
    save do
      @kv.each do |key, value|
        if key.starts_with?(starts_with)
          yield key, value
        end
      end
    end
  end

  def garbage_collect
    save do
      path = @log.path
      alt_path = "#{path}.1"
      File.delete(alt_path) if File.exists?(alt_path)

      @log.flush
      @log.close

      sync = @sync

      @log = File.new(alt_path, "w")
      @sync = false

      @log.write_byte(VERSION.to_u8)
      @kv.each do |key, value|
        log_write(key, value)
      end
      @log.flush
      @log.close

      @sync = sync

      File.delete(path)
      File.rename(alt_path, path)

      @log = File.new(path, "a")
    end
  end

  @channel_lock = Channel(Nil).new

  def lock
    @channel_lock.send nil
  end

  @channel_unlock = Channel(Nil).new

  def unlock
    @channel_unlock.send nil
  end

  def save
    lock
    yield
  ensure
    unlock
  end

  private def manage_locks
    while @running
      op = @channel_lock.receive
      op = @channel_unlock.receive
    end
    @log.flush
    @log.close
  end

  private def log_write(key, value)
    log Opcode::WRITE, key, value
  end

  private def log_remove(key)
    log Opcode::REMOVE, key
  end

  private def log_rename(key_old, key_new)
    log Opcode::RENAME, key_old, key_new
  end

  private def log(opcode, arg0, arg1 = nil)
    @log.write_byte(opcode.value.to_u8)

    write_string_arg(@log, arg0)
    write_string_arg(@log, arg1) if arg1

    @log.flush if @sync
  end

  private def write_string_arg(io, value)
    data = value.bytes

    io.write_bytes(data.size.to_i32, IO::ByteFormat::NetworkEndian)
    data.each do |b|
      io.write_byte(b)
    end
  end

  private def read_file_to_kv(path)
    kv = Hash(String, String).new

    file = File.new(path)
    version = file.read_byte.not_nil!
    raise Exception.new("Unsupported Version #{version}") if version != 1

    begin
      while opcode = file.read_byte
        case Opcode.new opcode
        when Opcode::WRITE
          key = read_string_arg file
          value = read_string_arg file

          kv[key] = value
        when Opcode::REMOVE
          key = read_string_arg file

          kv.delete key
        when Opcode::RENAME
          key_old = read_string_arg file
          key_new = read_string_arg file

          kv[key_new] = kv[key_old]
          kv.delete key_old
        else
          raise Exception.new("Invalid format: Opcode #{opcode}")
        end
      end
    rescue ex : IO::EOFError
      puts "Data is incomplete. \
            Please set sync to true to prevent this type of data corruption"
      puts "Continue..."
      @need_gc = true
    end
    file.close
    kv
  end

  private def read_string_arg(io)
    size = read_int(io)
    read_string(io, size)
  end

  private def read_int(io)
    value = 0
    4.times { value <<= 8; value += io.read_byte.not_nil! }
    value
  end

  private def read_string(io, size)
    data = Slice(UInt8).new(size)
    io.read_fully(data)
    String.new(data)
  end
end
