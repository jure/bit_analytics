bit_analytics: a powerful analytics library for Redis for Ruby
=================================================================

This Ruby gem (a port of [@amix's bitmapist library for Python](https://github.com/Doist/bitmapist)) makes it possible to implement real-time, highly scalable analytics that can answer following questions:

* Has user 123 been online today? This week? This month?
* Has user 123 performed action "X"?
* How many users have been active have this month? This hour?
* How many unique users have performed action "X" this week?
* How many % of users that were active last week are still active?
* How many % of users that were active last month are still active this month?

This gem is very easy to use and enables you to create your own reports easily.

Using Redis bitmaps you can store events for millions of users in a very little amount of memory (megabytes).
You should be careful about using huge ids (e.g. 2^32 or bigger) as this could require larger amounts of memory.

If you want to read more about bitmaps please read following:

* http://blog.getspool.com/2011/11/29/fast-easy-realtime-metrics-using-redis-bitmaps/
* http://redis.io/commands/setbit
* http://en.wikipedia.org/wiki/Bit_array
* http://www.slideshare.net/crashlytics/crashlytics-on-redis-analytics
* http://amix.dk/blog/post/19714 [my blog post]

Requires Redis 2.6+.

Installation
============

Can be installed very easily via:

$ gem install bit_analytics

Ports
=====

* Original Python library: https://github.com/Doist/bitmapist
* PHP port: https://github.com/jeremyFreeAgent/Bitter

Examples
========

Setting things up:

```ruby
require 'date'
now = Time.now.getutc
last_month = (Date.today << 1).to_time

# This connects to the default Redis (localhost:6379)
@bit_analytics = BitAnalytics.new

# You can also use custom Redis options
@bit_analytics = BitAnalytics.new(host: "10.0.1.1", port: 6380)
```

Mark user 123 as active and has played a song:

```ruby
@bit_anaytics.mark_event('active', 123)
@bit_anaytics.mark_event('song:played', 123)
```

Answer if user 123 has been active this month:

```ruby
@bit_analytics.month_events('active', now.year, now.month).includes?(123)
@bit_analytics.month_events('song:played', now.year, now.month).includes?(123)
@bit_analytics.month_events('active', now.year, now.month).has_events_marked == true
```

How many users have been active this week?:

```ruby
this_week = Time.now.strftime('%V')
@bit_analytics.week_events('active', now.year, this_week)
```

Perform bit operations. How many users that have been active last month are still active this month?

```ruby
active_2_months = @bit_analytics.bit_op_and(
    @bit_analytics.month_events('active', last_month.year, last_month.month),
    @bit_analytics.month_events('active', now.year, now.month)
)
puts active_2_months.length
 
# Is 123 active for 2 months?
active_2_months.includes?(123)
```

Work with nested bit operations (imagine what you can do with this ;-))!

```ruby
active_2_months = @bit_analytics.bit_op_and(
    @bit_analytics.bit_op_and(
        @bit_analytics.month_events('active', last_month.year, last_month.month),
        @bit_analytics.month_events('active', now.year, now.month)
    ),
    @bit_analytics.month_events('active', now.year, now.month)
)
puts active_2_months.length
active_2_months.includes?(123)

# Delete the temporary AND operation
active_2_months.delete
```

Tracking hourly is disabled by default to save memory, but you can supply an extra argument to `mark_event` to track events hourly:

```ruby
@bit_analytics.mark_event('active', 123, track_hourly: true)
```

Original library: Copyright: 2012 by Doist Ltd. Developer: Amir Salihefendic ( http://amix.dk ) License: BSD

Ruby port: Copyright 2014 Jure Triglav License: BSD

