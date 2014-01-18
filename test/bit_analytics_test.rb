require 'date'
require 'test/unit'
require 'bit_analytics'

class BitAnalyticsTest < Test::Unit::TestCase
  def setup
    @bit_analytics = BitAnalytics.new
  end

  def test_mark_with_diff_days
    @bit_analytics.delete_all_events
    @bit_analytics.mark_event('active', 123, track_hourly: true)

    now = Time.now.getutc

    # E.g. ['2014', '03'] for 17th of January 2014
    iso_date = now.strftime('%Y-%V').split('-')

    # Month
    assert @bit_analytics.month_events('active', now.year, now.month).includes?(123)
    assert !@bit_analytics.month_events('active', now.year, now.month).includes?(124)

    # Week
    assert @bit_analytics.week_events('active', now.year, iso_date[1]).includes?(123)
    assert !@bit_analytics.week_events('active', now.year, iso_date[1]).includes?(124)

    # Day
    assert @bit_analytics.day_events('active', now.year, now.month, now.day).includes?(123)
    assert !@bit_analytics.day_events('active', now.year, now.month, now.day).includes?(124)

    # Hour
    assert @bit_analytics.hour_events('active', now.year, now.month, now.day, now.hour).includes?(123)
    assert !@bit_analytics.hour_events('active', now.year, now.month, now.day, now.hour).includes?(124)
    assert !@bit_analytics.hour_events('active', now.year, now.month, now.day, now.hour-1).includes?(124)
  end

  def test_mark_counts
      @bit_analytics.delete_all_events

      now = Time.now.getutc
      assert @bit_analytics.month_events('active', now.year, now.month).get_count == 0

      @bit_analytics.mark_event('active', 123)
      @bit_analytics.mark_event('active', 23232)

      assert @bit_analytics.month_events('active', now.year, now.month).length == 2
  end

  def test_different_dates
    @bit_analytics.delete_all_events

    now = Time.now.getutc
    yesterday = (Date.today - 1).to_time

    @bit_analytics.mark_event('active', 123, now: now)
    @bit_analytics.mark_event('active', 23232, now: yesterday)

    assert @bit_analytics.day_events('active',
      now.year,
      now.month,
      now.day).get_count == 1

    assert @bit_analytics.day_events('active',
      yesterday.year,
      yesterday.month,
      yesterday.day).get_count == 1
  end

  def test_different_buckets
    @bit_analytics.delete_all_events

    now = Time.now.getutc

    @bit_analytics.mark_event('active', 123)
    @bit_analytics.mark_event('tasks:completed', 23232)

    assert @bit_analytics.month_events('active', now.year, now.month).get_count == 1
    assert @bit_analytics.month_events('tasks:completed', now.year, now.month).get_count == 1
  end

  def test_bit_operations
    @bit_analytics.delete_all_events

    now = Time.now.getutc
    last_month = (Date.today << 1).to_time

    # 123 has been active for two months
    @bit_analytics.mark_event('active', 123, now: now)
    @bit_analytics.mark_event('active', 123, now: last_month)

    # 224 has only been active last_month
    @bit_analytics.mark_event('active', 224, now: last_month)

    # Assert basic premises
    assert @bit_analytics.month_events('active', last_month.year, last_month.month).get_count == 2
    assert @bit_analytics.month_events('active', now.year, now.month).get_count == 1

    # Try out with bit AND operation
    active_2_months = @bit_analytics.bit_op_and(
        @bit_analytics.month_events('active', last_month.year, last_month.month),
        @bit_analytics.month_events('active', now.year, now.month)
    )
    assert active_2_months.get_count == 1
    assert active_2_months.includes?(123)
    assert !(active_2_months).includes?(224)
    active_2_months.delete

    # Try out with bit OR operation
    assert @bit_analytics.bit_op_or(
        @bit_analytics.month_events('active', last_month.year, last_month.month),
        @bit_analytics.month_events('active', now.year, now.month)
    ).get_count == 2

    # Try nested operations
    active_2_months = @bit_analytics.bit_op_and(
        @bit_analytics.bit_op_and(
            @bit_analytics.month_events('active', last_month.year, last_month.month),
            @bit_analytics.month_events('active', now.year, now.month)
        ),
        @bit_analytics.month_events('active', now.year, now.month)
    )

    assert active_2_months.includes?(123)
    assert !active_2_months.includes?(224)
    active_2_months.delete
  end
  
  def test_events_marked
    @bit_analytics.delete_all_events

    now = Time.now.getutc

    assert @bit_analytics.month_events('active', now.year, now.month).get_count == 0
    assert @bit_analytics.month_events('active', now.year, now.month).has_events_marked == false

    @bit_analytics.mark_event('active', 123, now: now)

    assert @bit_analytics.month_events('active', now.year, now.month).get_count == 1
    assert @bit_analytics.month_events('active', now.year, now.month).has_events_marked == true
  end
end

