require "io"

class Nuummite
  VERSION = 1
  property sync : Bool
  @log : File
  @kv : Hash(String, String)
  property autoclean_after_writes : Int32? = 10_000_000

  class Opcode
    RENAME = 3
    REMOVE = 2
    WRITE  = 1
  end

  def initialize(folder : String, @filename = "db.nuummite", @sync = true)
    @need_clean = false
    @log, @kv = open_folder(folder, @filename)
    @channel = Channel(Proc(Nil)).new
    @running = true
    spawn do
      run
    end
    clean if @need_clean
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

  macro do_save(block)
    raise Exception.new("already shutdown") unless @running
    @channel.send ->() do
      {{block}}
      nil
    end
  end

  @writes = 0
  private def check_autoclean
    if autoclean = @autoclean_after_writes
      @writes += 1
      if @writes > autoclean
        @writes = 0
        clean
      end
    end
  end

  macro save_blocking(block)
    raise Exception.new("already shutdown") unless @running
    ch = Channel(Nil).new
    @channel.send ->() do
      {{block}}
      ch.send(nil)
      nil
    end
    ch.receive
  end

  def shutdown
    save_blocking begin
      @running = false
      @log.flush
    end
  end

  def delete(key)
    ch = Channel(String?).new
    do_save begin
      log_remove(key)
      ch.send @kv.delete(key)
    end
    res = ch.receive
    check_autoclean
    res
  end

  def []=(key, value)
    ch = Channel(String?).new
    do_save begin
      log_write(key, value)
      ch.send @kv[key] = value
    end
    res = ch.receive
    check_autoclean
    res
  end

  def [](key)
    @kv[key]
  end

  def []?(key)
    @kv[key]?
  end

  def clean
    save_blocking begin
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

  private def run
    while @running
      op = @channel.receive
      op.call
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
    @log.write_byte(opcode.to_u8)

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
        case opcode
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
      @need_clean = true
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
