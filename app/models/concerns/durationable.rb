module Durationable
  extend ActiveSupport::Concern

  def duration
    return "00:00:00" unless ended?

    Time.at(duration_seconds).utc.strftime("%H:%M:%S")
  end

  def duration_seconds
    return 0 unless ended?

    (ended_at - started_at).to_i
  end
end
