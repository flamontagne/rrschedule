require 'rrschedule.rb'
Time.zone = "America/New_York"

teams = ["Rockets","Jetpacks","Snakes","Cobras","Wolves","Huskies","Tigers","Lions","Moose","Sprinklers","Pacers","Cyclops","Munchkins","Magicians","French Fries"]
schedule=RRSchedule::Schedule.new(
                                :teams => teams,  #array of teams that will compete against each other in the season (can be any kind of object)
                                :playing_surfaces => ["A","B","C","D"], #list of available playing surfaces (volleyball fields, curling sheets, tennis courts, etc)
                                :wdays => [3], #day(s) of the week where games are played
                                :start_date => Time.zone.parse("2010/10/13"), #Season will start on...                
                                :exclude_dates => [ #array of dates WITHOUT games
                                                    Time.zone.parse("2010/11/24"),
                                                    Time.zone.parse("2010/12/15"),
                                                    Time.zone.parse("2010/12/22"),
                                                    Time.zone.parse("2010/12/29")
                                                  ],
                                :cycles => 1, #1 for Round Robin, 2 for Double Round Robin and so on
                                :shuffle_initial_order => true, #Shuffle team order before each cycle
                                :game_times => ["10:00 AM", "1:00 PM"] #Times of the day where the games are played
                              )
res=schedule.generate

#human readable schedule
puts schedule.to_s

schedule.rounds.each do |round|
  puts "Round ##{round.round}"
  round.games.each do |g|
    puts g.team_a.to_s + " Vs " + g.team_b.to_s
  end
  puts "\n"
end

#display a team schedule
#test_team = "Sprinklers"
#games=schedule.by_team(test_team)
#puts "Schedule for team ##{test_team.to_s}"
#games.each do |g|
#  puts "#{g.game_date.strftime("%Y-%m-%d")}: against #{g.team_a == test_team ? g.team_b.to_s : g.team_a.to_s} on playing surface ##{g.playing_surface} at #{g.game_time}"     
#end

#face_to_face
#games=schedule.face_to_face("Lions","Moose")
#puts "FACE TO FACE: Lions Vs Moose"
#games.each do |g|
#  puts g.game_date.to_s + " on playing surface " + g.playing_surface.to_s + " at " + g.game_time.to_s
#end

#How to iterate the schedule
#schedule.gamedays.each do |gd,games|
#  puts gd
#  puts "===================="
#  games.each do |g|
#    puts g.team_a.to_s + " Vs " + g.team_b.to_s + " on playing surface ##{g.playing_surface} at #{g.game_time}"     
#  end
#  puts "\n"
#end
