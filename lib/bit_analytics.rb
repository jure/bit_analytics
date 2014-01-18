require "bit_analytics/version"
require 'redis'

class BitAnalytics
  attr_accessor :redis

  def initialize(options=nil)
    @redis = if options
      Redis.new(options)
    else
      Redis.new
    end
  end

  #--- Events marking and deleting ---
  # Marks an event for hours, days, weeks and months.
  # :param :event_name The name of the event, could be "active" or "new_signups"
  # :param :uuid An unique id, typically user id. The id should not be huge, read Redis documentation why (bitmaps)
  # :param :now Which date should be used as a reference point, default is `datetime.utcnow`
  # :param :track_hourly Should hourly stats be tracked, defaults to bitanalytics.TRACK_HOURLY, but an be changed
  # Examples:
  # Mark id 1 as active
  # mark_event('active', 1)
  # Mark task completed for id 252
  # mark_event('tasks:completed', 252)
  def mark_event(event_name, uuid, now: nil, track_hourly: nil)
    # Has memory applications
    track_hourly ||= false
    now ||= Time.now.getutc
    # E.g. ['2014', '03'] for 17th of January 2014
    iso_date = now.strftime('%Y-%V').split('-')

    events = [
      MonthEvents.new(event_name, now.year, now.month),
      WeekEvents.new(event_name, iso_date[0], iso_date[1]),
      DayEvents.new(event_name, now.year, now.month, now.day),
    ]

    if track_hourly
      events << HourEvents.new(event_name, now.year, now.month, now.day, now.hour) 
    end

    @redis.pipelined do 
      events.each do |event|
        @redis.setbit(event.redis_key, uuid, 1)
      end
    end
  end

  # Delete all events from the database.
  def delete_all_events
    keys = @redis.keys('bitanalytics_*')
    @redis.del(*keys) unless keys.empty?
  end

  # Delete all temporary keys that are used when using bit operations.
  def delete_temporary_bitop_keys
    keys = @redis.keys('bitanalytics_bitop_*')
    @redis.del(keys) unless keys.empty?
  end

  #--- Events ---

  def month_events(event_name, year, month)
    month_events = MonthEvents.new(event_name, year, month)
    month_events.redis = @redis
    month_events
  end

  def week_events(event_name, year, week)
    week_events = WeekEvents.new(event_name, year, week)
    week_events.redis = @redis
    week_events
  end

  def day_events(event_name, year, month, day)
    day_events = DayEvents.new(event_name, year, month, day)
    day_events.redis = @redis
    day_events
  end

  def hour_events(event_name, year, month, day, hour)
    hour_events = HourEvents.new(event_name, year, month, day, hour)
    hour_events.redis = @redis
    hour_events
  end

  #--- BitOps ---

  def bit_op_and(event, *events)
    bit_operation = BitOperation.new('AND', event, *events)
    bit_operation.redis = @redis
    bit_operation.execute
    bit_operation
  end

  def bit_op_or(event, *events)
    bit_operation = BitOperation.new('OR', event, *events)
    bit_operation.redis = @redis
    bit_operation.execute
    bit_operation
  end

  def bit_op_xor(event, *events)
    bit_operation = BitOperation.new('XOR', event, *events)
    bit_operation.redis = @redis
    bit_operation.execute
    bit_operation
  end

  #--- Private ---

  def _prefix_key(event_name, date)
    return 'bitanalytics_%s_%s' % [event_name, date]
  end

  #--- Events ---

  # Extends with an obj.has_events_marked()
  # that returns `True` if there are any events marked,
  # otherwise `False` is returned.

  # Extens also with a obj.delete()
  # (useful for deleting temporary calculations).

  module MixinEventsMisc
    def has_events_marked
      @redis.get(@redis_key) != nil
    end
    def delete
      @redis.del(@redis_key)
    end
  end

  # Extends with an obj.get_count() that uses BITCOUNT to
  # count all the events. Supports also __len__

  module MixinCounts
    def get_count
      @redis.bitcount(@redis_key)
    end
    
    def length
      return get_count
    end
  end

  # Makes it possible to see if an uuid has been marked.
  # Example: 
  # user_active_today = 123 in DayEvents('active', 2012, 10, 23)
  module MixinContains
    def includes?(uuid)
      if @redis.getbit(self.redis_key, uuid) == 1
        true
      else
        false
      end
    end
  end

  module RedisConnection
    attr_accessor :redis
    attr_reader :redis_key
  end
end


# Events for a month.
# Example:
# MonthEvents('active', 2012, 10)
class MonthEvents < BitAnalytics
  include RedisConnection
  include MixinCounts
  include MixinContains
  include MixinEventsMisc

  attr_reader :redis_key
  
  def initialize(event_name, year, month)
    @redis_key = _prefix_key(event_name,'%s-%s' % [year, month])
  end
end

# Events for a week.
# Example:
# WeekEvents('active', 2012, 48)
class WeekEvents < BitAnalytics
  include RedisConnection
  include MixinCounts
  include MixinContains
  include MixinEventsMisc
  
  def initialize(event_name, year, week)
    @redis_key = _prefix_key(event_name,'W%s-%s' % [year, week])
  end
end

# Events for a day.
# Example:
# DayEvents('active', 2012, 10, 23)
class DayEvents < BitAnalytics
  include RedisConnection
  include MixinCounts
  include MixinContains
  include MixinEventsMisc

  def initialize(event_name, year, month, day)
    @redis_key = _prefix_key(event_name,'%s-%s-%s' % [year, month, day])
  end
end

# Events for a hour.
# Example:
# HourEvents('active', 2012, 10, 23, 13)
class HourEvents < BitAnalytics
  include RedisConnection
  include MixinCounts
  include MixinContains
  include MixinEventsMisc

  def initialize(event_name, year, month, day, hour)
    @redis_key = _prefix_key(event_name,'%s-%s-%s-%s' % [year, month, day, hour])
  end
end

#--- Bit operations ---
# Base class for bit operations (AND, OR, XOR).
# Please note that each bit operation creates a new key prefixed with `bitanalytics_bitop_`.
# These temporary keys can be deleted with `delete_temporary_bitop_keys`.

# You can even nest bit operations.
# Example:
#     active_2_months = BitOpAnd(
#         MonthEvents('active', last_month.year, last_month.month),
#         MonthEvents('active', now.year, now.month)
#     )
#     active_2_months = BitOpAnd(
#         BitOpAnd(
#             MonthEvents('active', last_month.year, last_month.month),
#             MonthEvents('active', now.year, now.month)
#         ),
#         MonthEvents('active', now.year, now.month)
#     )
class BitOperation < BitAnalytics
  include MixinContains
  include MixinCounts
  include MixinEventsMisc
  include RedisConnection

  def initialize(op_name, *events)
    @op_name = op_name
    @event_redis_keys = events.map(&:redis_key)
    @redis_key = 'bitanalytics_bitop_%s_%s' % [@op_name, @event_redis_keys.join('-')]
  end

  def execute
    @redis.bitop(@op_name, @redis_key, @event_redis_keys)
  end
end
