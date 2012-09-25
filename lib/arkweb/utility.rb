module ARKWEB

# Utility functions and classes
module Utility

  # Timer.time reports the time since the last call to Timer.reset
  class Timer
    def self.reset
      @@start = Time.now
    end
    def self.time
      t = Time.now - @@start
      t.round(2).to_s.ljust(5,'0')
    end
    reset
  end

  # Write to standard output according to a standard format and verbosity
  # options
  def say(msg, sym='...', loud=false)
    return false if Conf[:quiet]
    return false if loud && !Conf[:verbose]
    unless msg == ''
      time = Timer.time.to_s.ljust(4, '0')
      puts "#{time} #{sym} #{msg}"
    else
      puts
    end
  end
  def msg(str)
    say(str, '>>>', false)
  end
  def dbg(str)
    say(str, '...', true)
  end
  def wrn(str)
    say(str, '???', true)
  end

  def root(*args)
    File.join(Root, *args)
  end

end # module Utility
end # module ARKWEB

