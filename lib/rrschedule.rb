# rrschedule (Round Robin Schedule generator)
# Auhtor: François Lamontagne
############################################################################################################################
module RRSchedule
  class Schedule
    attr_reader :cycles, :start_date, :exclude_dates,
                :shuffle_initial_order, :optimize, :teams, :nteams, :rounds, :gamedays, :rules


    def initialize(params={})
      @gamedays = []
      self.teams = params[:teams]
      self.cycles = params[:cycles]
      self.optimize = params[:optimize]
      self.shuffle_initial_order = params[:shuffle_initial_order]
      self.exclude_dates = params[:exclude_dates]
      self.start_date = params[:start_date]
      self.rules = params[:rules]
      self
    end

    #Array of teams that will compete against each other. You can pass it any kind of object
    def teams=(arr)
      @teams = arr ? arr.clone : [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]

      #nteams (stands for normalized teams. We don't modify the original array anymore).
      @nteams = @teams.clone

      #If teams aren't grouped, we create a single group and put all teams in it. That way
      #we won't have to check if this is a grouped round-robin or not every time.
      @nteams = [@nteams] unless @nteams.first.respond_to?(:to_ary)

      @nteams.each_with_index do |team_group,i|
        raise ":dummy is a reserved team name. Please use something else" if team_group.member?(:dummy)
        raise "at least 2 teams are required" if team_group.size == 1
        raise "teams have to be unique" if team_group.uniq.size < team_group.size
        @nteams[i] << :dummy if team_group.size.odd?
      end
    end



    def rules=(rules)
      @rules = rules || [Rule.new(
        :wday => 1,
        :gt => ["7:00PM"],
        :ps => ["Field #1"]
      )]
    end

    #Number of times each team plays against each other
    def cycles=(cycles)
      @cycles = cycles || 1
    end

    #Setting this to true will fill all the available playing surfaces and game times for a given gameday no matter if
    #one team has to play several games on the same gameday. Setting it to false make sure that teams won't play
    #more than one game per day.
    def optimize=(opt)
      @optimize = opt.nil? ? true : opt
    end

    #Shuffle the team order at the beginning of every cycles.
    def shuffle_initial_order=(shuffle)
      @shuffle_initial_order = shuffle.nil? ? true : shuffle
    end

    #Array of dates without games
    def exclude_dates=(dates)
      @exclude_dates=dates || []
    end

    #When the season starts? Since we generate the game dates based on weekdays, you need to pass it
    #a start date in the correct timezone to get accurate game dates for the whole season. Otherwise
    #you might
    def start_date=(date)
      @start_date=date || Date.today
    end


    #This will generate the schedule based on the various parameters
    def generate(params={})

      @nteams.each_with_index do |teams,division_id|
        current_cycle = current_round = 0
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
          ####
          current_round += 1

          #add the round in memory
          @rounds ||= []
          @rounds[division_id] ||= []
          @rounds[division_id] << Round.new(
            :round => current_round,
            :games => games.collect { |g|
              Game.new(
                :team_a => g[:team_a],
                :team_b => g[:team_b]
              )
            }
          )
          ####

          #if we have completed a full round-robin for the current division
          if current_round == teams.size-1
            current_cycle += 1
          end

        end until current_round == teams.size-1 && current_cycle==self.cycles
      end

      slice(@rounds)
      self
    end

    #returns an array of Game instances where team_a and team_b are facing each other
    def face_to_face(team_a,team_b)
      res=[]
      self.gamedays.each do |gd|
        res << gd.games.select {|g| (g.team_a == team_a && g.team_b == team_b) || (g.team_a == team_b && g.team_b == team_a)}
      end
      res.flatten
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

    #return an array of Game instances where 'team' is playing
    def by_team(team)
      gms=[]
      self.gamedays.each do |gd|
        gms << gd.games.select{|g| g.team_a == team || g.team_b == team}
      end
      gms.flatten
    end

    #returns true if the generated schedule is a valid round-robin (for testing purpose)
    def round_robin?
      #each round-robin round should contains n-1 games where n is the nbr of teams (:dummy included if odd)
      return false if self.rounds.size != (@teams.size*self.cycles)-self.cycles

      #check if each team plays the same number of games against each other
      self.teams.each do |t1|
        self.teams.reject{|t| t == t1}.each do |t2|
          return false unless self.face_to_face(t1,t2).size == self.cycles || [t1,t2].include?(:dummy)
        end
      end
      return true
    end

    private
    #Slice games according to playing surfaces available and game times
    def slice(rounds)
#      rounds = [
#        [
#          [
#            :round => 1,
#            :games => []
#          ],
#          [
#            :round => 2,
#            :games => []
#          ],
#          ...
#        ],
#
#        [],
#        [],
#      ]

      nbr_of_rounds = rounds.first.size
      nbr_of_divisions = rounds.size
      nbr_of_rounds.times do |round_id|
        nbr_of_divisions.times do |division_id|
          rounds[division_id][round_id].games.each do |game|
            #Here we need to add each game at the correct place depending on the rules

#            gameday.games << Game.new(
#              :team_a => game.team_a,
#              :team_b => game.team_b,
#              :game_date => cur_date,
#              :game_time => cur_gt,
#              :playing_surface => cur_ps
#            )
          end
        end
      end

    end

    #get the next gameday
    def next_game_date(dt,wday)
      dt += 1 until wday == dt.wday && !self.exclude_dates.include?(dt)
      dt
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

    #how many games can we play per day?
    def games_per_day
      self.ps.size * self.gt.size
    end

    def wday=(wday)
      @wday = wday ? wday : 1
      raise "Rule#wday must be between 0 and 6" unless (0..6).include?(@wday)
    end

    #Array of available playing surfaces. You can pass it any kind of object
    def ps=(ps)
      @ps = Array(ps).empty? ? ["Surface A", "Surface B"] : Array(ps)
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
      DateTime.parse(self.gt.first) <=> DateTime.parse(other.gt.first) :
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
    attr_accessor :round, :games

    def initialize(params={})
      self.round = params[:round]
      self.games = params[:games] || []
    end
  end
end
