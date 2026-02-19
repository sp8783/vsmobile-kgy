module TimestampParseable
  extend ActiveSupport::Concern

  private

  def parse_timestamp(str)
    return nil if str.blank?
    parts = str.strip.split(":").map(&:to_i)
    case parts.size
    when 3 then parts[0] * 3600 + parts[1] * 60 + parts[2]
    when 2 then parts[0] * 60 + parts[1]
    else nil
    end
  end

  def format_timestamp(seconds)
    return "" if seconds.nil?
    h, remainder = seconds.divmod(3600)
    m, s = remainder.divmod(60)
    "#{h}:#{format('%02d', m)}:#{format('%02d', s)}"
  end
end
