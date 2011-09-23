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
