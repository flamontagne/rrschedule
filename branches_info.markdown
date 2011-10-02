# Branches summary

The objective of this file is to share the intention behind every new branches that are created for RRSchedule. Since each branch
generally represents a "development effort", I think it is useful to describe and explain them.

## Rules and multiple round-robins (branch created on 2011/01/21)

### Rules

The idea behind having "rules" is to allow more flexibility in the schedule generation.

At the moment, we can tell RRSchedule that the games are played (for example) every monday and wednesday at 7:00PM and 9:00PM on four different
playing surfaces. But what if games played on monday are held at 7:00PM while games played on wednesday are held at 7:00PM and 9:00PM?
You just cannot configure it this way at the moment. And what if on monday every playing surfaces are available while only 1 is available on wednesday?
This is why I had the idea of replacing the current "one size fits all" system with a more flexible system.

Thus, we will be able to have rules like:

    Day of week | Game Time | playing surfaces   |
    Monday      | 7:00PM    | Field #1, Field #2 |
    Wednesday   | 7:00PM    | Field #1           |
    Wednesday   | 9:00PM    | Field #1

In the code it might look something like this:

    schedule.rules << Rule.new(:wday => 1, :gt => "7:00PM", :ps => ["Field #1", "Field #2"])
    schedule.rules << Rule.new(:wday => 3, :gt => "7:00PM", :ps => "Field #1")
    schedule.rules << Rule.new(:wday => 3, :gt => "9:00PM", :ps => "Field #1")

    schedule.generate

    ...

### Multiple round-robins

The other development in this branch involves the possibility to create multiple round-robins in the same method call while sharing the same
physical constraints (game times and playing surfaces)

Several sport leagues use a "division" system where teams are seeded in different groups based on their performance. Each group plays
a round-robin *inside* its own division. Suppose a league of 4 divisions containing 8 teams each. A1 will play against A2, A3 and so on but not
against B1, C3 or D6. What we need in this case is 4 different round-robins. However, these 4 round-robins share the same playing surfaces and
game times.

In other words, you will be able to do something like this:

    schedule.teams = [
      [A1,A2,A3,A4,A5,A6,A7,A8],
      [B1,B2,B3,B4,B5,B6,B7,B8],
      [C1,C2,C3,C4,C5,C6,C7,C8],
      [D1,D2,D3,D4,D5,D6,D7,D8]
    ]

    schedule.rules << Rule.new(
      ... #same rules apply for all 32 teams
    )

## Playing locations should be distributed evenly amongst competitors (branch created on 2011/09/23)

At the moment the playing locations are distributed randomly for every matchup. It means that one team
might play a lot more often on a playing field than on another.

The work in this branch will try to fix this issue. 

## Optional balancing for Game Times (branch crated on 2011/10/02)

I created this branch to solve a very specific case. When you generate a schedule with multiple divisions, you generally want that all
teams of a given division plays at the same game times. (e.g. Division A plays at 7:00, B plays at 9:00 and so on). However with the new 
balancing feature (see 2011/09/23 branch), it is no longer possible to achieve this.

I will add options balanced_gt and balanced_ps, both true by default.
