# rrschedule (Round Robin Schedule generator)
# Auhtor: François Lamontagne
############################################################################################################################
module RRSchedule
  class Schedule
    attr_reader :flights, :rounds, :gamedays
    attr_accessor :teams, :rules, :cycles, :start_date, :exclude_dates,:shuffle

    def initialize(params={})
      @gamedays = []
      self.teams = params[:teams] || []
      self.cycles = params[:cycles] || 1
      self.shuffle = params[:shuffle].nil? ? true : params[:shuffle]
      self.exclude_dates = params[:exclude_dates] || []
      self.start_date = params[:start_date] || Date.today
      self.rules = params[:rules] || []
      self
    end

    #This will generate the schedule based on the various parameters
    def generate(params={})
      raise "You need to specify at least 1 team" if @teams.nil? || @teams.empty?
      raise "You need to specify at least 1 rule" if @rules.nil? || @rules.empty?

      arrange_flights
      init_stats

      @gamedays = []; @rounds = []


      @flights.each_with_index do |teams,flight_id|
        current_cycle = current_round = 0
        teams = teams.sort_by{rand} if @shuffle

        #loop to generate the whole round-robin(s) for the current flight
        begin
          t = teams.clone
          games = []

          #process one round
          while !t.empty? do
            team_a = t.shift
            team_b = t.reverse!.shift
            t.reverse!

            x = [team_a,team_b].shuffle

            matchup = {:team_a => x[0], :team_b => x[1]}
            games << matchup
          end
          #done processing round

          current_round += 1

          #Team rotation (the first team is fixed)
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
            current_round = 0 if current_cycle < self.cycles
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
        gd.games.sort{|g1,g2| g1.gt == g2.gt ? g1.ps <=> g2.ps : g1.gt <=> g2.gt}.each do |g|
          res << "#{g.ta.to_s} VS #{g.tb.to_s} on playing surface #{g.ps} at #{g.gt.strftime("%I:%M %p")}\n"
        end
        res << "\n"
      end
      res
    end

    #returns true if the generated schedule is a valid round-robin (for testing purpose)
    def round_robin?(flight_id=0)
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

    def arrange_flights
      #a flight is a division where teams play round-robin against each other
      @flights = Marshal.load(Marshal.dump(@teams)) #deep clone

      #If teams aren't in flights, we create a single flight and put all teams in it
      @flights = [@flights] unless @flights.first.respond_to?(:to_ary)

      @flights.each_with_index do |flight,i|
        raise ":dummy is a reserved team name. Please use something else" if flight.member?(:dummy)
        raise "at least 2 teams are required" if flight.size < 2
        raise "teams have to be unique" if flight.uniq.size < flight.size
        @flights[i] << :dummy if flight.size.odd?
      end
    end

    #Dispatch games according to available playing surfaces and game times
    def dispatch_games(rounds)
      rounds_copy =  Marshal.load(Marshal.dump(rounds)) #deep clone
      cur_flight_index = 0

      while !rounds_copy.flatten.empty? do
        cur_round = rounds_copy[cur_flight_index].shift
        #process the next round in the current flight
        if cur_round
          cur_round.games.each do |game|
            dispatch_game(game) unless [game.team_a,game.team_b].include?(:dummy)
          end
        end

        if cur_flight_index == @flights.size-1
          cur_flight_index = 0
        else
          cur_flight_index += 1
        end
      end

      #We group our schedule by gameday
      s=@schedule.group_by{|fs| fs[:gamedate]}.sort
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
    end

    def dispatch_game(game)
      if @cur_rule.nil?
        @cur_rule = @rules.select{|r| r.wday >= self.start_date.wday}.first || @rules.first
        @cur_rule_index = @rules.index(@cur_rule)
        reset_resource_availability
      end

      @cur_gt = get_best_gt(game)
      @cur_ps = get_best_ps(game,@cur_gt)

      @cur_date ||= next_game_date(self.start_date,@cur_rule.wday)
      @schedule ||= []

      #if one of the team has already plays at this gamedate, we change rule
      if @schedule.size>0
        games_this_date = @schedule.select{|v| v[:gamedate] == @cur_date}
        if games_this_date.select{|g| [game.team_a,game.team_b].include?(g[:team_a]) || [game.team_a,game.team_b].include?(g[:team_b])}.size >0
          @cur_rule_index = (@cur_rule_index < @rules.size-1) ? @cur_rule_index+1 : 0
          @cur_rule = @rules[@cur_rule_index]
          reset_resource_availability
          @cur_gt = get_best_gt(game)
          @cur_ps = get_best_ps(game,@cur_gt)
          @cur_date = next_game_date(@cur_date+=1,@cur_rule.wday)
        end
      end

      #We found our playing surface and game time, add the game in the schedule.
      @schedule << {:team_a => game.team_a, :team_b => game.team_b, :gamedate => @cur_date, :ps => @cur_ps, :gt => @cur_gt}
      update_team_stats(game,@cur_gt,@cur_ps)
      update_resource_availability(@cur_gt,@cur_ps)


      #If no resources left, change rule
      x = @gt_ps_avail.reject{|k,v| v.empty?}
      if x.empty?
        if @cur_rule_index < @rules.size-1
          last_rule=@cur_rule
          @cur_rule_index += 1
          @cur_rule = @rules[@cur_rule_index]
          #Go to the next date (except if the new rule is for the same weekday)
          @cur_date = next_game_date(@cur_date+=1,@cur_rule.wday) if last_rule.wday != @cur_rule.wday
        else
          @cur_rule_index = 0
          @cur_rule = @rules[@cur_rule_index]
          @cur_date = next_game_date(@cur_date+=1,@cur_rule.wday)
        end
        reset_resource_availability
      end
    end

    #get the next gameday
    def next_game_date(dt,wday)
      dt += 1 until wday == dt.wday && !self.exclude_dates.include?(dt)
      dt
    end

    def update_team_stats(game,cur_gt,cur_ps)
      @stats[game.team_a][:gt][cur_gt] += 1
      @stats[game.team_a][:ps][cur_ps] += 1
      @stats[game.team_b][:gt][cur_gt] += 1
      @stats[game.team_b][:ps][cur_ps] += 1
    end

    def get_best_gt(game)
      x = {}
      gt_left = @gt_ps_avail.reject{|k,v| v.empty?}
      gt_left.each_key do |gt|
        x[gt] = [
          @stats[game.team_a][:gt][gt] + @stats[game.team_b][:gt][gt],
          rand(1000)
        ]
      end
      x.sort_by{|k,v| [v[0],v[1]]}.first[0]
    end

    def get_best_ps(game,gt)
      x = {}
      @gt_ps_avail[gt].each do |ps|
        x[ps] = [
          @stats[game.team_a][:ps][ps] + @stats[game.team_b][:ps][ps],
          rand(1000)
        ]
      end
      x.sort_by{|k,v| [v[0],v[1]]}.first[0]
    end

    def reset_resource_availability
      @gt_ps_avail = {}
      @cur_rule.gt.each do |gt|
        @gt_ps_avail[gt] = @cur_rule.ps.clone
      end
    end

    def update_resource_availability(cur_gt,cur_ps)
      @gt_ps_avail[cur_gt].delete(cur_ps)
    end


    #return matchups between two teams
    def face_to_face(team_a,team_b)
      res=[]
      self.gamedays.each do |gd|
        res << gd.games.select {|g| (g.team_a == team_a && g.team_b == team_b) || (g.team_a == team_b && g.team_b == team_a)}
      end
      res.flatten
    end

    #Count the number of times each team plays on a given playing surface and at what time. That way
    #we can balance the available playing surfaces/game times among competitors.
    def init_stats
      @stats = {}
      @teams.flatten.each do |t|
        @stats[t] = {:gt => {}, :ps => {}}
        all_gt.each { |gt| @stats[t][:gt][gt] = 0 }
        all_ps.each { |ps| @stats[t][:ps][ps] = 0 }
      end
    end

    #returns an array of all available game times / playing surfaces, all rules included.
    def all_gt; @rules.collect{|r| r.gt}.flatten.uniq; end
    def all_ps; @rules.collect{|r| r.ps}.flatten.uniq; end
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
