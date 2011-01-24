# rrschedule (Round Robin Schedule generator)
# Auhtor: François Lamontagne
############################################################################################################################
module RRSchedule
  class Schedule
    attr_reader :teams, :flights, :rounds, :gamedays                
    attr_accessor :rules, :cycles, :start_date, :exclude_dates,:shuffle_initial_order

    def initialize(params={})
      @gamedays = []
      self.teams = params[:teams] if params[:teams]
      self.cycles = params[:cycles] || 1
      self.shuffle_initial_order = params[:shuffle_initial_order].nil? ? true : params[:shuffle_initial_order]
      self.exclude_dates = params[:exclude_dates] || []      
      self.start_date = params[:start_date] || Date.today
      self.rules = params[:rules] || []
      self
    end

    #Array of teams that will compete against each other. You can pass it any kind of object
    def teams=(arr)
      @teams = Marshal.load(Marshal.dump(arr)) #deep clone

      #a flight is a division where teams play round-robin against each other
      @flights = Marshal.load(Marshal.dump(@teams)) #deep clone

      #If teams aren't in flights, we create a single flight and put all teams in it
      @flights = [@flights] unless @flights.first.respond_to?(:to_ary)
      @flights.each_with_index do |flight,i|
        raise ":dummy is a reserved team name. Please use something else" if flight.member?(:dummy)
        raise "at least 2 teams are required" if flight.size == 1
        raise "teams have to be unique" if flight.uniq.size < flight.size
        @flights[i] << :dummy if flight.size.odd?
      end
    end

    #This will generate the schedule based on the various parameters
    def generate(params={})
      @gamedays = []
      @rounds = []
      
      @flights.each_with_index do |teams,flight_id|
        current_cycle = current_round = 0
        teams = teams.sort_by{rand} if @shuffle_initial_order
        
        #loop to generate the whole round-robin(s) for the current flight
        begin
          t = teams.clone
          games = []

          #process one round
          while !t.empty? do
            team_a = t.shift
            team_b = t.reverse!.shift
            t.reverse!

            matchup = {:team_a => team_a, :team_b => team_b}
            games << matchup
          end
          #done processing round
          
          current_round += 1

          #Team rotation
          teams = teams.insert(1,teams.delete_at(teams.size-1))
          
          #add the round in memory
          @rounds ||= []
          @rounds[flight_id] ||= []
          @rounds[flight_id] << Round.new(
            :round => current_round,
            :flight => flight_id,
            :games => games.collect { |g|
              Game.new(
                :team_a => g[:team_a],
                :team_b => g[:team_b]
              )              
            }
          )
          #done adding round

          #have we completed a full round-robin for the current flight?
          if current_round == teams.size-1            
            current_cycle += 1
            
            if current_cycle < self.cycles 
              current_round = 0 
              teams = teams.sort_by{rand} if @shuffle_initial_order
            end
          end
        
        end until current_round == teams.size-1 && current_cycle==self.cycles
      end   
      
      dispatch_games(@rounds)
      self
    end

    #human readable schedule
    def to_s
      res = ""
      res << "#{self.gamedays.size.to_s} gamedays\n"
      self.gamedays.each do |gd|
        res << gd.date.strftime("%Y-%m-%d") + "\n"
        res << "==========\n"
        gd.games.each do |g|
          res << "#{g.ta.to_s} VS #{g.tb.to_s} on playing surface #{g.ps} at #{g.gt.strftime("%I:%M %p")}\n"
        end
        res << "\n"
      end
      res
    end

    #returns true if the generated schedule is a valid round-robin (for testing purpose)
    def round_robin?(flight_id=nil)
      #each round-robin round should contains n-1 games where n is the nbr of teams (:dummy included if odd)
      return false if self.rounds[flight_id].size != (@flights[flight_id].size*self.cycles)-self.cycles

      #check if each team plays the same number of games against each other
      @flights[flight_id].each do |t1|
        @flights[flight_id].reject{|t| t == t1}.each do |t2|
          return false unless face_to_face(t1,t2).size == self.cycles || [t1,t2].include?(:dummy)
        end
      end
      return true
    end

    private
    
    #Dispatch games according to available playing surfaces and game times
    #The flat schedule contains "place holders" for the actual games. Each row contains
    #a game date, a game time and a playing surface. We then process our rounds one by one
    #and we put each matchup in the next available slot of the flat schedule
    def dispatch_games(rounds)
      flat_schedule = generate_flat_schedule
    
      rounds_copy =  Marshal.load(Marshal.dump(rounds)) #deep clone
      nbr_of_flights = rounds_copy.size
      cur_flight = 0
      i=0
      while !rounds_copy.flatten.empty? do
        cur_round = rounds_copy[cur_flight].shift

        #process the next round in the current flight
        if cur_round          
          cur_round.games.each do |game|
            unless [game.team_a,game.team_b].include?(:dummy)            
              flat_schedule[i][:team_a] = game.team_a
              flat_schedule[i][:team_b] = game.team_b
              i+=1
            end
          end
        end
        

        if cur_flight == nbr_of_flights-1
          cur_flight = 0
        else
          cur_flight += 1          
        end        
      end
      
      #We group our flat schedule by gameday        
      s=flat_schedule.group_by{|fs| fs[:gamedate]}.sort
      s.each do |gamedate,gms|      
        games = []
        gms.each do |gm|    
          games << Game.new(
            :team_a => gm[:team_a],
            :team_b => gm[:team_b],
            :playing_surface => gm[:ps],
            :game_time => gm [:gt] 
          )
        end
        self.gamedays << Gameday.new(:date => gamedate, :games => games)
      end      
      self.gamedays.each { |gd| gd.games.reject! {|g| g.team_a.nil?}}
    end


    def generate_flat_schedule
      flat_schedule = []
      games_left = max_games_per_day = day_game_ctr = rule_ctr = 0

      #determine first rule based on the nearest gameday
      cur_rule  = @rules.select{|r| r.wday >= self.start_date.wday}.first || @rules.first
      cur_rule_index = @rules.index(cur_rule)
      cur_date = next_game_date(self.start_date,cur_rule.wday)
      
      @flights.each do |flight|
        games_left += @cycles * (flight.include?(:dummy) ? ((flight.size-1)/2.0)*(flight.size-2) : (flight.size/2)*(flight.size-1))
        max_games_per_day += (flight.include?(:dummy) ? (flight.size-2)/2.0 : (flight.size-1)/2.0).ceil
      end

      #process all games
      while games_left > 0 do
        cur_rule.gt.each do |gt|
          cur_rule.ps.each do |ps|          
          
            #if there are more physical resources (playing surfaces and game times) for a given day than
            #we need, we don't use them all (or else some teams would play twice on a single day)
            if day_game_ctr <= max_games_per_day-1
              flat_schedule << {:gamedate => cur_date, :gt => gt, :ps => ps}
              games_left -= 1; day_game_ctr += 1
            end
          end                
        end

        last_rule = cur_rule
        last_date = cur_date

        #Advance to the next rule (if we're at the last one, we go back to the first)
        cur_rule_index = (cur_rule_index == @rules.size-1) ? 0 : cur_rule_index + 1
        cur_rule = @rules[cur_rule_index]
                
        #Go to the next date (except if the new rule is for the same weekday)
        if cur_rule.wday != last_rule.wday || @rules.size==1
          cur_date = next_game_date(cur_date+=1,cur_rule.wday)          
          day_game_ctr = 0          
        end        
      end      
      flat_schedule
    end
    
    #get the next gameday
    def next_game_date(dt,wday)
      dt += 1 until wday == dt.wday && !self.exclude_dates.include?(dt)
      dt
    end
    
    #return matchups between two teams
    def face_to_face(team_a,team_b)
      res=[]
      self.gamedays.each do |gd|
        res << gd.games.select {|g| (g.team_a == team_a && g.team_b == team_b) || (g.team_a == team_b && g.team_b == team_a)}
      end
      res.flatten
    end    
  end

  class Gameday
    attr_accessor :date, :games

    def initialize(params)
      self.date = params[:date]
      self.games = params[:games] || []
    end

  end

  class Rule
    attr_accessor :wday, :gt, :ps


    def initialize(params)
      self.wday = params[:wday]
      self.gt = params[:gt]
      self.ps = params[:ps]
    end

    def wday=(wday)
      @wday = wday ? wday : 1
      raise "Rule#wday must be between 0 and 6" unless (0..6).include?(@wday)
    end

    #Array of available playing surfaces. You can pass it any kind of object
    def ps=(ps)
      @ps = Array(ps).empty? ? ["Field #1", "Field #2"] : Array(ps)
    end

    #Array of game times where games are played. Must be valid DateTime objects in the string form
    def gt=(gt)
      @gt =  Array(gt).empty? ? ["7:00 PM"] : Array(gt)
      @gt.collect! do |gt|
        begin
          DateTime.parse(gt)
        rescue
          raise "game times must be valid time representations in the string form (e.g. 3:00 PM, 11:00 AM, 18:20, etc)"
        end
      end
    end

    def <=>(other)
      self.wday == other.wday ?
      DateTime.parse(self.gt.first.to_s) <=> DateTime.parse(other.gt.first.to_s) :
      self.wday <=> other.wday
    end
  end

  class Game
    attr_accessor :team_a, :team_b, :playing_surface, :game_time, :game_date
    alias :ta :team_a
    alias :tb :team_b
    alias :ps :playing_surface
    alias :gt :game_time
    alias :gd :game_date

    def initialize(params={})
      self.team_a = params[:team_a]
      self.team_b = params[:team_b]
      self.playing_surface = params[:playing_surface]
      self.game_time = params[:game_time]
      self.game_date = params[:game_date]
    end
  end

  class Round
    attr_accessor :round, :games,:flight

    def initialize(params={})
      self.round = params[:round]
      self.flight = params[:flight]
      self.games = params[:games] || []
    end
    
    def to_s
      str = "FLIGHT #{@flight.to_s} - Round ##{@round.to_s}\n"
      str += "=====================\n"
      
      self.games.each do |g|
        if [g.team_a,g.team_b].include?(:dummy)
          str+= g.team_a == :dummy ? g.team_b.to_s : g.team_a.to_s + " has a BYE\n"
        else
          str += g.team_a.to_s + " Vs " + g.team_b.to_s + "\n"
        end
      end
      str += "\n"
    end
  end
end
