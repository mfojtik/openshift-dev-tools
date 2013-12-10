require 'time'
require 'erb'
require 'cgi'

class PlatformLogAnalyze

  TIMESTAMP_FORMAT = /(\w+\s\d+\s\d{2}:\d{2}:\d{2})/
  ENTRY_REGEX = /^#{TIMESTAMP_FORMAT}\s(INFO|ERROR).*/

  def initialize(filename)
    @log = File.open(filename)
  end

  def emit
    current_entry = ""
    @log.each_line do |line|
      (current_entry+=line) && next if current_entry.empty?
      if line =~ ENTRY_REGEX
        yield process(current_entry)
        (current_entry = line) && next
      end
      current_entry += line
    end
  end

  def process(entry)
    entries = entry.split("\n")
    result = {}
    result[:title] = entries.first.strip
    result[:timestamp] = result[:title].scan(TIMESTAMP_FORMAT).first[0]
    result[:title].gsub!(result[:timestamp], '')
    result[:severity] = result[:title].scan(/\s(INFO|ERROR)\s/).first[0]
    result[:title].gsub!(result[:severity], '')
    entries.shift
    result[:messages] = entries
    Entry.new(result)
  end

  class Entry
    attr_reader :timestamp, :severity, :title, :messages

    def initialize(opts={})
      @timestamp = DateTime.parse(opts[:timestamp].strip)
      @severity = "#{opts[:severity]}".downcase.strip.to_sym
      @title = opts[:title].strip
      @messages = opts[:messages]
      analyze_return_code!
    end

    def analyze_return_code!
      @severity = :warning if @title =~ /rc=([1-9]+)/
      @severity = :warning if @messages.any? { |m| m =~ /(error|fail|unable|cannot|warn)/}
    end

  end

end

# Escape HTML
#
def h(text)
  CGI.escapeHTML(text)
end

def timeago(time)
  time_ago = ((Time.now - time) / 86400) # returns a number in days
  # Less than a day ago
  if time_ago < 1 
    time_ago *= 24
    # Less than an hour ago
    if time_ago < 1
      time_ago *= 60
      # Less than a minute ago
      if time_ago < 1
        time_ago *= 60
        return "#{time_ago = time_ago.round}" + ((time_ago == 1) ? " second ago" :  " seconds ago")
      end
      return "#{time_ago = time_ago.round}" + ((time_ago == 1) ? " minute ago" :  " minutes ago")
    end
    return "#{time_ago = time_ago.round}" + ((time_ago == 1) ? " hour ago" :  " hours ago")
  elsif time_ago == 1
    return "#{time_ago = time_ago.round} day ago"
  else
    return "#{time_ago = time_ago.round} days ago"
  end
end

log = PlatformLogAnalyze.new('sample/platform.log')
template = ERB.new(File.read('templates/platform.erb'))
puts template.result(binding)
