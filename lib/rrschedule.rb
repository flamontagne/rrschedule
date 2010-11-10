# rrschedule (Round Robin Schedule generator)
# Auhtor: François Lamontagne
############################################################################################################################
require 'active_support'
module RRSchedule
  class Schedule
    attr_accessor :playing_surfaces, :game_times, :cycles, :wdays, :start_date, :exclude_dates, :shuffle_initial_order
    attr_reader :teams, :rounds

    def initialize(params={})
      self.teams = params[:teams] || [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
      self.playing_surfaces = Array(params[:playing_surfaces]).empty? ? ["Surface A", "Surface B"] : Array(params[:playing_surfaces])
      self.cycles = params[:cycles] || 1
      
      self.game_times = Array(params[:game_times]).empty? ? ["7:00 PM", "9:00 PM"] : Array(params[:game_times])
      self.game_times.collect! do |gt| 
        begin
          DateTime.parse(gt) 
        rescue
          raise "game times must be valid time representations in the string form (e.g. 3:00 PM, 11:00 AM, 18:20, etc)"
        end
      end
      
      self.shuffle_initial_order = params[:shuffle_initial_order].nil? ? true : params[:shuffle_initial_order]
      self.exclude_dates = params[:exclude_dates] || []
      self.start_date = params[:start_date] || Time.now.beginning_of_day
      self.wdays = Array(params[:wdays]).empty? ? [1] : Array(params[:wdays])
      
      raise "each value in wdays must be between 0 and 6" if self.wdays.reject{|w| (0..6).member?(w)}.size > 0
      self
    end
    
        
    def generate(params={})
      @teams = @teams.sort_by{rand} if self.shuffle_initial_order
      initial_order = @teams.clone
      current_cycle = 0
      current_round = 0
      all_games = []      

      #Loop start here
      begin
        games = []
        t = @teams.clone
        while !t.empty? do
          team_a = t.shift
          team_b = t.reverse!.shift
          t.reverse!
          games << {:team_a => team_a, :team_b => team_b}
          all_games << {:team_a => team_a, :team_b => team_b}
        end
        #round completed
        current_round += 1
        @rounds ||= []
        @rounds << Round.new( 
                    :round => current_round,
                    :games => games.collect { |g| Game.new( 
                                                    :team_a => g[:team_a],
                                                    :team_b => g[:team_b])
                                            })
        
        reject_dummy = lambda {|g| g[:team_a] == :dummy || g[:team_b] == :dummy}
        games.reject! {|g| reject_dummy.call(g)}
        all_games.reject! {|g| reject_dummy.call(g)}
          
        @teams = @teams.insert(1,@teams.delete_at(@teams.size-1))
        
        #If we have completed a cycle
        if @teams == initial_order
          current_cycle += 1        
          #Shuffle the teams at each cycle
          if current_cycle <= self.cycles && self.shuffle_initial_order
            @teams = @teams.sort_by{rand}
            initial_order = @teams.clone
          end
        end
      end until @teams == initial_order && current_cycle==self.cycles
      #@teams.delete(:dummy)
      slice(all_games)
      self
    end


    def face_to_face(team_a,team_b)
      res=[]
      self.gamedays.each do |gd,games|
        res << games.select {|g| (g.team_a == team_a && g.team_b == team_b) || (g.team_a == team_b && g.team_b == team_a)}
      end
      res.flatten
    end
    
    def to_s
      res = ""
      res << "#{@schedule.keys.size.to_s} gamedays\n"    
      @schedule.sort.each do |gd,games|
        res << gd.strftime("%Y-%m-%d") + "\n"
        res << "==========\n"
        games.each do |g|
          res << "#{g.team_a.to_s} VS #{g.team_b.to_s} on playing surface #{g.playing_surface} at #{g.game_time.strftime("%I:%M %p")}\n"
        end
        res << "\n"
      end
      res
    end
    
    def gamedays
      @schedule.sort
    end        
    
    #TODO: should return either a Schedule instance or a TeamSchedule instance (this class doesn't exist yet)
    def by_team(team)      
      gms=[]
      self.gamedays.each do |gd,games|
        gms << games.select{|g| g.team_a == team || g.team_b == team}                
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
    
    def teams=(arr)
      @teams = arr.clone
      raise ":dummy is a reserved team name. Please use something else" if @teams.member?(:dummy)
      raise "at least 2 teams are required" if @teams.size == 1   
      @teams << :dummy if @teams.size.odd?
    end
        
    private      
    #Slice games according to playing surfaces and game times
    def slice(games)
      res={}    
      slices = games.each_slice(games_per_day)
      wdays_stack = self.wdays.clone     
      cur_date = self.start_date
      slices.each_with_index do |slice,i|
        gt_stack = self.game_times.clone.sort_by{rand}
        ps_stack = self.playing_surfaces.clone.sort_by{rand}
        wdays_stack = self.wdays.clone if wdays_stack.empty?

        cur_wday = wdays_stack.shift        
        cur_date = next_game_date(cur_date,cur_wday)
        cur_gt = gt_stack.shift
        
        res[cur_date] = []
        slice.each_with_index do |g,game_index|          
          cur_ps = ps_stack.shift
          res[cur_date] << Game.new(
                            :team_a => g[:team_a], 
                            :team_b => g[:team_b], 
                            :playing_surface => cur_ps, 
                            :game_time => cur_gt, 
                            :game_date => cur_date)
          cur_gt = gt_stack.shift if ps_stack.empty?            
          gt_stack = self.game_times.clone if gt_stack.empty?          
          ps_stack = self.playing_surfaces.clone if ps_stack.empty?                              
        end
        
        res[cur_date] = res[cur_date].sort_by {|g| [g.game_time,g.playing_surface]}
        cur_date += 1.day
      end
      @schedule = res        
    end
    
    def next_game_date(dt,wday)
      dt += 1.days until wday == dt.wday && !self.exclude_dates.include?(dt)
      dt
    end
    
    def games_per_day
      self.playing_surfaces.size * self.game_times.size
    end
  end  
  
  class Game
    attr_accessor :team_a, :team_b, :playing_surface, :game_time, :game_date
    
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
      self.games = params[:games]
    end
  end
end

