require 'SysVIPC'
include SysVIPC

class B5mDaemon

  def initialize(path)
    file = File.expand_path(path)
    key = ftok(file, 0)
    @mq = MessageQueue.new(key, IPC_CREAT | 0660)
  end

  def run(cmd)
    @mq.send(1, cmd)
    puts "sent #{cmd}"
    while true
      sleep 2
      begin
        result = @mq.receive(2, 1004, IPC_NOWAIT)
        p = result.index("\x00")
        unless p.nil?
          result = result[0, p]
        end
        break
      rescue SystemCallError => e
        if e.errno==Errno::ENOMSG::Errno
          next
        else
          raise e
        end
      end
    end

    return (result=="succ")
  end

  def close
    @mq.rm
  end

end

