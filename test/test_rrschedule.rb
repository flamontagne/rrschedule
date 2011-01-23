require 'helper'
class TestRrschedule < Test::Unit::TestCase

  context "a new RRSchedule instance" do
    setup do
      @s= RRSchedule::Schedule.new
    end
    
    should "have default values for some options" do
      assert_equal 1, @s.cycles
      assert @s.shuffle_initial_order
      assert_equal Date.today, @s.start_date
      assert_equal [], @s.exclude_dates
    end
  end
  
  
  context "an instance with a teams array flattened" do
    setup do
       @s=RRSchedule::Schedule.new(:teams => %w(1 2 3 4 5 6))
    end    
    
    should "be wrapped into a single division in the normalized array" do
      assert_equal [%w(1 2 3 4 5 6)], @s.nteams
    end
    
    should "not modify the original array" do
      assert_equal %w(1 2 3 4 5 6), @s.teams
    end    
  end
  
  context "an instance with an odd number of teams" do
    setup do
      @s=RRSchedule::Schedule.new(:teams => %w(1 2 3 4 5))
    end
        
    should "add a dummy competitor in the normalized array" do
      assert_equal 6, @s.nteams.first.size
      assert @s.nteams.first.include?(:dummy)
    end
    
    should "not modify the original array" do
      assert_equal 5, @s.teams.size
      assert !@s.teams.include?(:dummy)      
    end
  end
  
  should "generate without fuss" do
    s = RRSchedule::Schedule.new
    s.teams = [
      %w(A1 A2 A3 A4 A5 A6 A7),
      %w(B1 B2 B3 B4 B5 B6 B7),
      %w(C1 C2 C3 C4 C5 C6 C7),
      %w(D1 D2 D3 D4 D5 D6 D7),
      %w(E1 E2 E3 E4 E5 E6 E7)
    ]
    s.rules = []
    s.rules << RRSchedule::Rule.new(:wday => 2, :gt => ["7:00PM","9:00PM"], :ps => [1,2,3,4,5,6,7,8])
    s.rules << RRSchedule::Rule.new(:wday => 0, :gt => ["7:00PM"], :ps => [1,2,3,4])
    s.start_date=Date.parse("2010/11/30")
    s.exclude_dates = [Date.parse("2010/12/26"),Date.parse("2011/01/23")]
    s.generate
#    s.rounds.each do |round|
#      puts round.to_s
#    end
#    puts s.to_s    
  end
end
