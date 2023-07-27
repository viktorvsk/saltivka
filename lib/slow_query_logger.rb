require "json"
require "digest"
require "logger"

class SlowQueryLogger
  def initialize(output, threshold)
    @threshold = threshold.to_i

    @logger = Logger.new(output)
    @logger.formatter = method(:formatter)
  end

  def call(name, start, finish, id, payload)
    # Skip transaction start/end statements
    return if /BEGIN|COMMIT/.match?(payload[:sql])

    duration = ((finish - start) * 1000).round(4)
    return unless duration >= @threshold

    data = {
      time: start.iso8601,
      pid: Process.pid,
      pname: $PROGRAM_NAME,
      duration: duration,
      query: payload[:sql].strip.gsub(/(^(\s+)?$\n)/, ""),
      length: payload[:sql].size,
      cached: payload[:cache] ? true : false,
      hash: Digest::SHA1.hexdigest(payload[:sql])
    }.compact

    @logger.warn(data)
  end

  private

  def formatter(severity, time, progname, data)
    "[SLOW] payload=#{JSON.dump(data)}" + "\n"
  end
end
