require 'helper'
class TestRrschedule < Test::Unit::TestCase
  context "new instance without params" do
    setup do
      @s= RRSchedule::Schedule.new
    end
    
    should "have default values for some options" do
      assert_equal 1, @s.cycles
      assert @s.shuffle
      assert_equal Date.today, @s.start_date
      assert_equal [], @s.exclude_dates
    end
  end      
  
  context "no flight" do
    setup do
       @s=RRSchedule::Schedule.new(:teams => %w(1 2 3 4 5 6))
    end    
    
    should "be wrapped into a single division in the normalized array" do
      assert_equal [%w(1 2 3 4 5 6)], @s.flights
    end
    
    should "not modify the original array" do
      assert_equal %w(1 2 3 4 5 6), @s.teams
    end    
  end

  context "odd number of teams without flight" do
    setup do
      @s=RRSchedule::Schedule.new(:teams => %w(1 2 3 4 5))
    end
        
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
  
  context "multi flights" do
    setup do
      @s = RRSchedule::Schedule.new(
        :teams => [
          %w(A1 A2 A3 A4 A5 A6 A7 A8),
          %w(B1 B2 B3 B4 B5 B6 B7 B8),
          %w(C1 C2 C3 C4 C5 C6 C7 C8),
          %w(D1 D2 D3 D4 D5 D6 D7 D8)
        ],
        
        :rules => [
          RRSchedule::Rule.new(
            :wday => 3, 
            :gt => ["7:00PM", "9:00PM"], 
            :ps => ["one","two"]
          )
        ],
        
        :start_date => Date.parse("2011/01/26"),
        :exclude_dates => [
          Date.parse("2011/02/02")
        ]
      ).generate
    end
    
    should "generate separate round-robins" do
      assert_equal 4, @s.flights.size      
      4.times { |i| assert @s.round_robin?(i)}
    end
    
    should "have a correct total number of games" do
      assert_equal 112, @s.gamedays.collect{|gd| gd.games.size}.inject{|x,sum| x+sum}
    end
    
    should "not have games for a date that is excluded" do
      assert !@s.gamedays.collect{|gd| gd.date}.include?(Date.parse("2011/02/02"))
      assert @s.gamedays.collect{|gd| gd.date}.include?(Date.parse("2011/02/09"))      
    end
    
    
    #pending tests
    should "not have a team that plays twice on the same gameday" do
      assert true
    end
    
  end

  ##### RULES #######
  context "multiple rules on the same weekday" do
    setup do
      @s = RRSchedule::Schedule.new
      @s.teams = [%w(a1 a2 a3 a4 a5), %w(b1 b2 b3 b4 b5 b6 b7 b8)]
      @s.rules = [
        RRSchedule::Rule.new(:wday => 4, :gt => ["7:00PM"], :ps => %w(field#1 field#2)),
        RRSchedule::Rule.new(:wday => 4, :gt => ["9:00PM"], :ps => %w(field#1 field#2 field#3))
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
          assert_equal 1, gd.games.select{|g| g.game_time == DateTime.parse("7:00PM") && g.playing_surface == "field#1"}.size
          assert_equal 1, gd.games.select{|g| g.game_time == DateTime.parse("7:00PM") && g.playing_surface == "field#2"}.size      
          assert_equal 1, gd.games.select{|g| g.game_time == DateTime.parse("9:00PM") && g.playing_surface == "field#1"}.size
          assert_equal 1, gd.games.select{|g| g.game_time == DateTime.parse("9:00PM") && g.playing_surface == "field#2"}.size      
          assert_equal 1, gd.games.select{|g| g.game_time == DateTime.parse("9:00PM") && g.playing_surface == "field#3"}.size
          cur_date += 7        
        end
      end
    end    
  end
end
