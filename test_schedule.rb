require 'rubygems'
require 'active_support/all'
require './lib/rrschedule.rb'
include RRSchedule
schedule=RRSchedule::Schedule.new(
              :teams => %w(T1 T2 T3 T4 T5 T6 T7 T8 T9 T10 T11 T12 T13 T14 T15 T16 T17 T18 T19 T20 T21 T22 T23 T24 T25 T26),
              :rules => [
                RRSchedule::Rule.new(
                  :wday => 3,
                  :gt => ["7:00 PM","9:00 PM"],
                  :ps => ["1","2","3","4","5","6"],
                )
              ],
              :shuffle => true,
              :start_date => Date.parse("2010/10/13")
            ).generate


require 'rubygems'
require 'active_support/all'
require './lib/rrschedule.rb'
include RRSchedule
schedule=RRSchedule::Schedule.new(
              :teams => %w(T1 T2 T3 T4 T5 T6 T7 T8 T9 T10 T11 T12 T13),
              :rules => [
                RRSchedule::Rule.new(
                  :wday => 3,
                  :gt => ["7:00 PM"],
                  :ps => ["1","2","3","4"],
                )
              ],
              :cycles => 3,
              :shuffle => true,
              :start_date => Date.parse("2010/10/13")
            ).generate
            
require 'rubygems'
require 'active_support/all'
require './lib/rrschedule.rb'
include RRSchedule
schedule=RRSchedule::Schedule.new(
              :teams => [
                %w(A1 A2 A3 A4 A5 A6 A7 A8),
                %w(B1 B2 B3 B4 B5 B6 B7 B8),
                %w(C1 C2 C3 C4 C5 C6 C7 C8),
                %w(D1 D2 D3 D4 D5 D6 D7 D8),
                %w(E1 E2 E3 E4 E5 E6 E7 E8),                                                                
              ],

              :rules => [
                RRSchedule::Rule.new(
                  :wday => 1,
                  :gt => ["7:00 PM"],
                  :ps => ["1","2","3","4"],
                ),
                RRSchedule::Rule.new(
                  :wday => 3,
                  :gt => ["7:00 PM","9:00 PM"],
                  :ps => ["1","2","3","4","5","6","7","8"],
                )
                
              ],
              :cycles => 1,
              :start_date => Date.parse("2010/10/13"),
              :balanced_gt => false,
              :balanced_ps => true
            ).generate            
