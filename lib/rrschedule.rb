# RRSchedule make it easier to generate Round-Robin sport seasons. To generate a schedule, it needs a team list, a season 
# start date, the day(s) of the week where the games are played and some other options.
#
# It takes into consideration physical constraints such as the number of playing surfaces availables and game times.
# Each round of the round-robin is splitted into groups that respect these constraints. 
#
# Say for example that you want to generate a round-robin schedule for your 15-teams volleyball league. 
# If there are only 3 volleyball fields available and that games are played each monday at 6PM and 8PM, this is technically 
# impossible to complete one round in a single day (only 6 games can be played). RRSchedule will put the rest of the games
# for this round on the next gameday and will start a new round right after.
#
# Version 0.1
# Auhtor: François Lamontagne
############################################################################################################################

require 'rubygems'
require 'active_support'


module RRSchedule
  class Schedule
    attr_accessor :playing_surfaces, :game_times, :cycles, :wdays, :start_date, :exclude_dates, :shuffle_initial_order
    attr_reader :teams

    def initialize(params={})
      store_params(params)
    end
    
        
    def generate(params={})
      @teams = @teams.sort_by{rand} if self.shuffle_initial_order
      initial_order = @teams.clone
      current_cycle = 0
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
        games.reject! {|g| g[:team_a] == :dummy || g[:team_b] == :dummy}
        all_games.reject! {|g| g[:team_a] == :dummy || g[:team_b] == :dummy}
          
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
      @teams.delete(:dummy)
      slice(all_games)      
    end


    def face_to_face(team_a,team_b)
      res=[]
      self.gamedays.each do |gd,games|
        res << games.select{|g| (g.team_a == team_a && g.team_b == team_b) || (g.team_a == team_b && g.team_b == team_a)}
      end
      res.flatten
    end
    
    def to_s
      res = ""
      res << "#{@schedule.keys.size.to_s} gamedays\n"    
      @schedule.sort.each do |gd,games|
        gd_proc = lambda {gd.strftime("%Y-%m-%d")}
        res << gd_proc.call + "\n"
        res << "=" * gd_proc.call.length + "\n"
        games.each do |g|
          res << g.team_a.to_s + " VS " + g.team_b.to_s + " on playing surface #{g.playing_surface} at #{g.game_time}\n"
        end
        res << "\n"
      end
      res
    end
    
    def gamedays
      @schedule.sort
    end
    
    def by_team(team)
      gms=[]
      self.gamedays.each do |gd,games|
        #games = games.each {|g| g.game_date = gd}
        gms << games.select{|g| g.team_a == team || g.team_b == team}
      end
      gms.flatten
    end

    private  

    def teams=(arr)
      @teams = arr.clone
      @teams << :dummy if arr.size.odd?
    end
    
    #Let's slice our games according to our physical constraints
    def slice(games)
      res={}    
      slices = games.each_slice(games_per_day)
      wdays_stack = self.wdays.clone
            
      cur_date = self.start_date
      slices.each_with_index do |slice,i|
        gt_stack = self.game_times.clone
        ps_stack = self.playing_surfaces.clone
        wdays_stack=self.wdays.clone if wdays_stack.empty?        

        cur_wday = wdays_stack.shift        
        cur_date = next_game_date(cur_date,cur_wday)
        cur_gt = gt_stack.shift
        
        res[cur_date] = []
        slice.each_with_index do |g,game_index|          
          cur_ps = ps_stack.shift
          res[cur_date] << Game.new(:team_a => g[:team_a], :team_b => g[:team_b], :playing_surface => cur_ps, :game_time => cur_gt, :game_date => cur_date)
          cur_gt = gt_stack.shift if ps_stack.empty?            
          gt_stack = self.game_times.clone if gt_stack.empty?          
          ps_stack = self.playing_surfaces.clone if ps_stack.empty?                              
        end
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

    def store_params(params)
      self.teams = params[:teams] if params[:teams].respond_to?(:to_ary)
      self.playing_surfaces = params[:playing_surfaces] if params[:playing_surfaces].respond_to?(:to_ary)      
      self.cycles = params[:cycles] if params[:cycles].respond_to?(:to_int)
      self.game_times = params[:game_times] if params[:game_times].respond_to?(:to_ary)
      self.shuffle_initial_order = params[:shuffle_initial_order]
      self.exclude_dates = params[:exclude_dates] || []
      self.start_date = params[:start_date] || Time.now.beginning_of_day
      self.wdays = Array(params[:wdays]) if params[:wdays].respond_to?(:to_ary) || params[:wdays].respond_to?(:to_int)
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
end

