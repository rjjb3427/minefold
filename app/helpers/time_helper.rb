module TimeHelper

  def time_left(coins)
    d = coins.minutes

    case d
    when (-Float::INFINITY)..0
      "No time"
    when 1...(1.hour)
      pluralize(d / 1.minute, 'min', 'mins')
    else
      pluralize(d / 1.hour, 'hr', 'hrs')
    end
  end
  
  def prepaid_time_left(coins)
    d = coins.minutes
    
    case d
    when (-Float::INFINITY)..0
      "No time"
    when 1...(1.hour)
      pluralize(d / 1.minute, "minute", "minutes")
    else
      pluralize(d / 1.hour, "hour", "hours")
    end
  end

end
