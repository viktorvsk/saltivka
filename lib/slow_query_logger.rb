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
      duration: duration,
      length: payload[:sql].size,
      cached: payload[:cache] ? true : false,
      query: JSON.dump(payload[:sql].strip.gsub(/(^(\s+)?$\n)/, "")),
      hash: Digest::SHA1.hexdigest(payload[:sql])
      time: start.iso8601,
      pid: Process.pid,
      pname: $PROGRAM_NAME,
    }.compact

    @logger.warn(data)
  end

  private

  def formatter(severity, time, progname, data)
    params_string = data.map { |pair| pair.join("=") }.join(" ")

    "[SLOW] #{params_string}" + "\n"
  end
end
