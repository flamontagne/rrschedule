require 'helper'
require 'active_support/all'
class TestRrschedule < Test::Unit::TestCase
  include RRSchedule
  context "new instance without params" do
    setup {@s= Schedule.new}
    should "have default values for some options" do
      assert_equal 1, @s.cycles
      assert @s.shuffle
      assert_equal Date.today, @s.start_date
      assert_equal [], @s.exclude_dates
    end
  end

  context "no teams" do
    setup {@s = Schedule.new(:rules => [Rule.new(:wday => 1, :gt => ["7:00PM"], :ps => %w(one two))])}
    should "raise an exception" do
      exception = assert_raise(RuntimeError){@s.generate}
      assert_equal "You need to specify at least 1 team", exception.message
    end
  end

  context "no flight" do
    setup{@s=Schedule.new(:teams => %w(1 2 3 4 5 6), :rules => some_rules)}
    should "be wrapped into a single flight in the normalized array" do
      @s.generate
      assert_equal [%w(1 2 3 4 5 6)], @s.flights
    end

    should "not modify the original array" do
      assert_equal %w(1 2 3 4 5 6), @s.teams
    end
  end

  context "odd number of teams without flight" do
    setup {@s=Schedule.new(:teams => %w(1 2 3 4 5),:rules => some_rules).generate}
    should "add a dummy competitor in the created flight" do
      assert_equal 1, @s.flights.size
      assert_equal 6, @s.flights.first.size
      assert @s.flights.first.include?(:dummy)
    end

    should "not modify the original array" do
      assert_equal 5, @s.teams.size
      assert !@s.teams.include?(:dummy)
    end
  end


  context "extra available resources" do
    setup do
      @s = Schedule.new(
        :teams => %w(a1 a2 a3 a4 a5),
        :rules => [
          Rule.new(
            :wday => 3,
            :gt => ["7:00PM", "9:00PM"],
            :ps => %w(one two three four)
          )
        ]
      ).generate
    end

    should "have a maximum of (teams/2) games per day" do
      @s.gamedays.each do |gd|
        assert gd.games.size <= @s.teams.size/2
      end
    end

    should "not have a team that play more than once on a single day" do
      @s.gamedays.each do |gd|
        day_teams = gd.games.collect{|g| [g.team_a,g.team_b]}.flatten
        unique_day_teams = day_teams.uniq
        assert_equal day_teams.size, unique_day_teams.size
      end
    end
  end


  context "multi flights" do
    setup do
      @s = Schedule.new(
        :teams => [
          %w(A1 A2 A3 A4 A5 A6 A7 A8),
          %w(B1 B2 B3 B4 B5 B6 B7 B8),
          %w(C1 C2 C3 C4 C5 C6 C7 C8),
          %w(D1 D2 D3 D4 D5 D6 D7 D8)
        ],

        :rules => [
          Rule.new(
            :wday => 3,
            :gt => ["7:00PM", "9:00PM"],
            :ps => ["one","two"]
          )
        ],

        :start_date => Date.parse("2011/01/26"),
        :exclude_dates => [
          Date.parse("2011/02/02")
        ]
      )
    end

    should "generate separate round-robins" do
      @s.generate
      assert_equal 4, @s.flights.size
      4.times { |i| assert @s.round_robin?(i)}
    end

    should "have a correct total number of games" do
      @s.generate    
      assert_equal 112, @s.gamedays.collect{|gd| gd.games.size}.inject{|x,sum| x+sum}
    end

    should "not have games for a date that is excluded" do
      @s.generate    
      assert !@s.gamedays.collect{|gd| gd.date}.include?(Date.parse("2011/02/02"))
      assert @s.gamedays.collect{|gd| gd.date}.include?(Date.parse("2011/02/09"))
    end
    
    should "respect rules" do
      @s.teams << %w(E1 E2 E3 E4 E5 E6 E7 E8)
      @s.rules << Rule.new(:wday => 4, :gt => "7:00PM", :ps => %w(one two))
      @s.generate
      
      wday = 3
      @s.gamedays.each do |gd|
        assert_equal wday, gd.date.wday
        wday = (wday==3) ? 4 : 3
      end
    end
  end

  ##### RULES #######
  should "auto create array for gt and ps" do
    @s = Schedule.new(
      :teams => %w(a1 a2 a4 a5),
      :rules => [
        Rule.new(:wday => 1, :gt => "7:00PM", :ps => "The Field")
      ]
    ).generate

    assert_equal [DateTime.parse("7:00PM")], @s.rules.first.gt
    assert_equal ["The Field"], @s.rules.first.ps
  end

  context "no rules specified" do
    setup {@s = Schedule.new(:teams => %w(a1 a2 a4 a5))}
    should "raise an exception" do
      exception = assert_raise(RuntimeError){@s.generate}
      assert_equal "You need to specify at least 1 rule", exception.message
    end
  end

  context "multiple rules on the same weekday" do
    setup do
      @s = Schedule.new
      @s.teams = [%w(a1 a2 a3 a4 a5 a6 a7 a8), %w(b1 b2 b3 b4 b5 b6 b7 b8)]
      @s.rules = [
        Rule.new(:wday => 4, :gt => ["7:00PM"], :ps => %w(field1 field2)),
        Rule.new(:wday => 4, :gt => ["9:00PM"], :ps => %w(field1 field2 field3))
      ]
      @s.start_date = Date.parse("2011/01/27")
      @s.generate
    end

    should "keep games on the same day" do
      cur_date = @s.start_date
      @s.gamedays.each_with_index do |gd,i|
        assert_equal cur_date, gd.date

        #check all days to make sure that our rules are respected. We don't check
        #the last one because it might not be full (round-robin over)
        if i<@s.gamedays.size-1
          assert_equal 5, gd.games.size
          assert_equal 1, gd.games.select{|g| g.game_time == DateTime.parse("7:00PM") && g.playing_surface == "field1"}.size
          assert_equal 1, gd.games.select{|g| g.game_time == DateTime.parse("7:00PM") && g.playing_surface == "field2"}.size
          assert_equal 1, gd.games.select{|g| g.game_time == DateTime.parse("9:00PM") && g.playing_surface == "field1"}.size
          assert_equal 1, gd.games.select{|g| g.game_time == DateTime.parse("9:00PM") && g.playing_surface == "field2"}.size
          assert_equal 1, gd.games.select{|g| g.game_time == DateTime.parse("9:00PM") && g.playing_surface == "field3"}.size
          cur_date += 7
        end
      end
    end
  end

  def some_rules
    [
      Rule.new(:wday => 1, :gt => "7:00PM", :ps => "one"),
      Rule.new(:wday => 1, :gt => "8:00PM", :ps => %w(one two))
    ]
  end
end
