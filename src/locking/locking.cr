# Allows basic locking.
module Locking
  @running = true
  @channel_lock = Channel(Nil).new
  @channel_unlock = Channel(Nil).new

  private def lock
    @channel_lock.send nil
  end

  private def unlock
    @channel_unlock.send nil
  end

  private def save
    lock
    yield
  ensure
    unlock
  end

  private def enable_locking
    spawn do
      manage_locks
    end
  end

  private def disable_locking
    save do
      @runnig = false
    end
  end

  private def manage_locks
    while @running
      op = @channel_lock.receive
      op = @channel_unlock.receive
    end
  end
end
