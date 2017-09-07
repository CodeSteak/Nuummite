require "./locking/*"

# Nuummite is a minimalistic persistent key-value store.
class Nuummite
  include Locking

  VERSION = 1

  # Number of writes or deletes before automatic garbage collection happens.
  #
  # Set it to nil to disable automatic garbage collection.
  property auto_garbage_collect_after_writes : Int32? = 10_000_000

  # If true the logfile is flushed on every write.
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

    enable_locking
    garbage_collect if @need_gc
  end

  private def open_folder(folder, filename) : {File, Hash(String, String)}
    Dir.mkdir(folder) unless Dir.exists?(folder)

    path = "#{folder}#{File::SEPARATOR}#{filename}"
    alt_path = "#{folder}#{File::SEPARATOR}#{filename}.1"

    new_file = false

    kv = if File.exists?(path) && File.size(path) > 0
           read_file_to_kv path
         elsif File.exists?(alt_path) && File.size(alt_path) > 0
           File.rename(alt_path, path)
           read_file_to_kv path
         else
           new_file = true
           Hash(String, String).new
         end

    file = File.new(path, "a")
    if new_file
      file.write_byte(VERSION.to_u8)
      file.flush
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

  # Shuts down this instance of Nuummite.
  def shutdown
    disable_locking
    @log.flush
    @log.close
  end

  # Delets a key. Returns its value.
  def delete(key)
    save do
      log_remove(key)
      @kv.delete(key)
    end
  ensure
    check_autogc
  end

  # Set key to value.
  def []=(key, value)
    save do
      log_write(key, value)
      @kv[key] = value
    end
  ensure
    check_autogc
  end

  # Reads value to given key.
  def [](key)
    @kv[key]
  end

  # Reads value to given key. Returns `nil` if key is not avilable.
  def []?(key)
    @kv[key]?
  end

  # Yields every key-value pair where the key starts with `starts_with`.
  # ```
  # db["crystals/ruby"] = "9.0"
  # db["crystals/quartz"] = "~ 7.0"
  # db["crystals/nuummite"] = "5.5 - 6.0"
  #
  # db.each("crystals/") do |key, value|
  #   # only crystals in here
  # end
  # ```
  # `starts_with` defaults to `""`. Then every key-value pair is yield.
  def each(starts_with : String = "")
    save do
      @kv.each do |key, value|
        if key.starts_with?(starts_with)
          yield key, value
        end
      end
    end
  end

  # Rewrites current state to logfile.
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
