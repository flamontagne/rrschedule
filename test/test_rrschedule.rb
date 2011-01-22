require 'helper'

class TestRrschedule < Test::Unit::TestCase

  should "generate without fuss" do
    s = RRSchedule::Schedule.new
    s.teams = [
      %w(A1 A2 A3 A4 A5 A6 A7 A8),
      %w(B1 B2 B3 B4 B5 B6 B7 B8),
      %w(C1 C2 C3 C4 C5 C6 C7 C8),
      %w(D1 D2 D3 D4 D5 D6 D7 D8)
    ]
    s.rules << RRSchedule::Rule.new(:wday => 2, :gt => ["7:00PM","9:00PM"], :ps => [1,2,3,4,5,6,7,8])
    s.rules << RRSchedule::Rule.new(:wday => 4, :gt => ["7:00PM","9:00PM"], :ps => [1,2,3,4,5,6,7,8])
    s.rules << RRSchedule::Rule.new(:wday => 0, :gt => ["7:00PM"], :ps => [1,2,3,4])
    s.generate
    s.rounds.each_with_index do |div_rounds,div_id|
      puts "DIVISION ##{div_id+1}"
      puts "====================="
      div_rounds.each_with_index do |round,j|
        puts "Round ##{j+1}"
        puts "=============="
        round.games.each do |g|
          puts g.team_a.to_s + " Vs " + g.team_b.to_s
        end
      end
    end
    
  end
  context "A Schedule instance" do
    should "have default values for every options" do
      schedule = RRSchedule::Schedule.new
      assert schedule.teams.size > 2
      assert_equal 1, schedule.cycles
      assert schedule.rules.respond_to?(:to_ary)
      assert_equal 1, schedule.rules.size

      #default rule if non supplied
      assert schedule.rules.first.is_a?(RRSchedule::Rule)
      assert_equal 1, schedule.rules.first.wday
      assert_equal DateTime.parse("7:00PM"), schedule.rules.first.gt.first
      assert_equal ["Field #1"], schedule.rules.first.ps
      ###

      assert schedule.start_date.is_a?(Date)
      assert schedule.shuffle_initial_order
      assert schedule.optimize
      assert schedule.exclude_dates.empty?
    end

    should "have a dummy team when number of teams is odd" do
      schedule = RRSchedule::Schedule.new(:teams => Array(1..9))
      assert schedule.nteams.first.size == 10
      assert schedule.nteams.first.member?(:dummy), "There should always be a :dummy team when the nbr of teams is odd"
    end

    should "not have a dummy team when number of teams is even" do
      schedule = RRSchedule::Schedule.new(:teams => Array(1..6))
      assert schedule.teams.size == 6
      assert !schedule.teams.member?(:dummy), "There should never be a :dummy team when the nbr of teams is even"
    end

    should "not have a team named :dummy in the initial array" do
      assert_raise RuntimeError do
        schedule = RRSchedule::Schedule.new(
          :teams => Array(1..4) << :dummy
        )
      end
    end

#    should "not have game times that cannot convert to valid DateTime objects" do
#      assert_raise RuntimeError do
#        schedule = RRSchedule::Schedule.new(
#          :teams => Array(1..4),
#          :game_times => ["10:00 AM", "13:00", "bonjour"]
#        )
#      end
#    end

#    should "not have wdays that are not between 0 and 6" do
#      assert_raise RuntimeError do
#        schedule = RRSchedule::Schedule.new(
#          :wdays => [2,7]
#        )
#      end
#    end

#    should "automatically convert game times and playing surface to arrays" do
#      schedule = RRSchedule::Schedule.new(
#        :teams => Array(1..4),
#        :game_times => "10:00 AM",
#        :playing_surfaces => "the only one"
#      )

#      assert_equal [DateTime.parse("10:00 AM")], schedule.game_times
#      assert_equal ["the only one"], schedule.playing_surfaces
#    end

    should "have at least two teams" do
      assert_raise RuntimeError do
        schedule = RRSchedule::Schedule.new(:teams => [1])
      end
    end

    should "have default teams if non was specified" do
      schedule = RRSchedule::Schedule.new
      assert schedule.nteams.first.size > 1
    end

    should "not have a team that is specified twice" do
      assert_raise RuntimeError do
        schedule = RRSchedule::Schedule.new(:teams => %w(a a b c d e f g h i))
      end

    end
  end

  context "Any valid schedule" do
    setup do
      @s = RRSchedule::Schedule.new(
        :teams => %w(a b c d e f g h i j l m),
        :playing_surfaces => %w(one two),
        :game_times => ["10:00 AM", "13:00 PM"]
      )
    end

#    should "have gamedays that respect the wdays attribute" do
#      @s.wdays = [3,5]
#      @s.generate

#      @s.gamedays.each do |gd|
#        assert [3,5].include?(gd.date.wday), "wday is #{gd.date.wday.to_s} but should be 3 or 5"
#      end
#    end

#    context "with the option optimize set to true" do
#      should "have at most (playing_surfaces*game_times) games per gameday" do
#        @s.generate
#        assert @s.gamedays.first.games.size == (@s.playing_surfaces.size * @s.game_times.size)
#      end
#    end

#    context "with the option optimize set to false" do
#      setup do
#        @s.optimize = false
#      end

#      should "never have more than (number of teams / 2) games per gameday" do
#        @s.teams = %w(only three teams)
#        @s.generate
#        assert @s.gamedays.first.games.size == @s.teams.size / 2
#      end
#    end

#    context "with an odd number of teams" do
#      setup do
#        @s = RRSchedule::Schedule.new(
#          :teams => %w(a b c d e f g h i j l),
#          :playing_surfaces => %w(one two),
#          :game_times => ["10:00 AM", "13:00 PM"]
#        ).generate
#      end

#      should "be a valid round-robin" do
#        assert @s.round_robin?
#      end

#      should "not have any :dummy teams in the final schedule" do
#        assert @s.gamedays.collect{|gd| gd.games}.flatten.select{
#          |g| [g.team_a,g.team_b].include?(:dummy)
#        }.size == 0
#      end
#    end

#    context "with an even number of teams" do
#      setup do
#        @s = RRSchedule::Schedule.new(
#          :teams => %w(a b c d e f g h i j l m),
#          :playing_surfaces => %w(one two),
#          :game_times => ["10:00 AM", "13:00 PM"]
#        ).generate
#      end

#      should "be a valid round-robin" do
#        assert @s.round_robin?
#      end

#      should "not have any :dummy teams in the final schedule" do
#        assert @s.gamedays.collect{|gd| gd.games}.flatten.select{
#          |g| [g.team_a,g.team_b].include?(:dummy)
#        }.size == 0
#      end
#    end
  end
end
