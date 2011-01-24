# RRSchedule #

RRSchedule makes it easier to generate round-robin schedules for sport leagues.

It takes into consideration the number of available playing surfaces and game times and split
games into gamedays that respect these contraints.

## Installation ##
    gem install rrschedule
    require 'rrschedule'

## Prepare the schedule ##
    schedule=RRSchedule::Schedule.new(
      #array of teams that will compete against each other. If you group teams into multiple flights (divisions),
      #a separate round-robin is generated in each of them but the "physical constraints" are shared
      :teams => [
        %w(A1 A2 A3 A4 A5 A6 A7 A8),
        %w(B1 B2 B3 B4 B5 B6 B7 B8)
      ],

      #Setup some scheduling rules
      :rules => [
        RRSchedule::Rule.new(:wday => 3, :gt => ["7:00PM","9:00PM"], :ps => ["field #1", "field #2"]),
        RRSchedule::Rule.new(:wday => 5, :gt => ["7:00PM"], :ps => ["field #1"])
      ],
          
      #First games are played on...
      :start_date => Date.parse("2010/10/13"),
      
      #array of dates to exclude
      :exclude_dates => [Date.parse("2010/11/24"),Date.parse("2010/12/15")],
                        
      #Number of times each team must play against each other (default is 1)
      :cycles => 1,
       
      #Shuffle team order before each cycle. Default is true
      :shuffle => true
    )

## Generate the schedule ##
    schedule.generate
  
## Playing with the output ##

### human readable schedule ###
    puts schedule.to_s

### Iterate through schedule ###
    schedule.gamedays.each do |gd|
      puts gd.date.strftime("%Y/%m/%d")
      puts "===================="
      gd.games.each do |g|
        puts g.team_a.to_s + " Vs " + g.team_b.to_s + " on playing surface ##{g.playing_surface} at #{g.game_time.strftime("%I:%M %p")}"     
      end
      puts "\n"
    end

### Display each round of the round-robin(s) without any date/time or playing location info ###
    puts s.rounds.collect{|r| r.to_s}

## Issues / Other ##

Hope this gem will be useful to some people!

You can read my [blog](http://www.rubyfleebie.com)
