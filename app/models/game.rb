# == Schema Information
#
# Table name: games
#has_many :game_team
#  id         :integer          not null, primary key
#  created_at :datetime
#  updated_at :datetime
#

class Game < ActiveRecord::Base
	has_many :teams, :dependent => :destroy
	has_many :goals, :dependent => :destroy
	has_many :positions, :through => :teams
	has_many :players, :through => :positions

	validate :teams_cannot_be_more_than_two
	#, :game_cannot_be_started_without_two_teams

	accepts_nested_attributes_for :teams, :allow_destroy => true
	
	enum color: [:red, :blue]

	scope :completed, -> { where.not(completed_at: nil) }


	#builds new team based a passed in team. 
	#Shifts players one spot moving from goalie to striker
	private
	def self.set_rematch_team(old_team, new_team)
		4.times do |old_team_index|
 			position = new_team.positions.build
 			position.position_type = old_team_index

 			#shift players from goalie to striker. look at last game played
 			current_player_id = old_team[old_team_index].player_id
 			l = (old_team_index-1)%4
 			while l != old_team_index
 				if current_player_id != old_team[l].player_id
 					position.player_id = old_team[l].player_id
 					break
 				end
 				l = (l-1)%4
 			end
 		end
	end


	public
	def self.new_game(params)
		game = self.new

 		#create the blue team
 		blueteam = Team.new_team(game)
 		blueteam.color = "blue"

 		#create the red team
 		redteam = Team.new_team(game)
 		redteam.color = "red"

 		return game
	end

	#Handles how we rematch games.
	#Teams rotate on table and each player is shifted a position over
	def self.new_rematch_game(params)
		lastgame = Game.includes(teams: [:positions]).find_by_id(params[:id])
 		lastredteam = lastgame.teams.red.first.positions.order("positions.position_type")
 		lastblueteam = lastgame.teams.blue.first.positions.order("positions.position_type")

 		rematch_game = self.new

 		#create the blue team
 		blueteam = rematch_game.teams.build
 		blueteam.color = "blue"

 		set_rematch_team(lastredteam, blueteam)

 		#create the red team
 		redteam = rematch_game.teams.build
 		redteam.color = "red"

 		set_rematch_team(lastblueteam, redteam)

 		return rematch_game
	end

	#Passed list of players as array of Player objects who are participating in the game
	#returns two teams in an array
	def self.generate_random_teams(players)
		team_index = 0
		#array of two team arrays
		teams = [[],[]]

 		while players.size() > 0
 			#grab a random player index
 			random_index = rand(0..(players.size()-1))
 			#remove player from available players
 			current_player = players.delete_at(random_index)
 			#stick player into current team
 			teams[team_index%teams.size()].push(current_player)
 			team_index += 1
 		end

 		return teams
	end

	def winning_team
		winningteam = self.teams.where(winner: true)
	end

	def undo_last_goal
		if self.completed_at != nil
			self.completed_at = nil
			self.teams.each do |team|
				team.winner = nil
				team.save
			end
			self.save
		end

		lastgoal = self.goals.order("created_at").last
 		lastgoal.delete
	end

	def get_game_score_at_goal(goal)
		blue_team = self.teams.blue.first
		red_team = self.teams.red.first

		blue_goals = blue_team.goals.scored_goal.where(["created_at <= ?", goal.created_at])
		red_goals = red_team.goals.scored_goal.where(["created_at <= ?", goal.created_at])
		red_own_goals = red_team.goals.own_goal.where(["created_at <= ?", goal.created_at])
		blue_own_goals = blue_team.goals.own_goal.where(["created_at <= ?", goal.created_at])

		score = {"blue_score" => blue_goals.count+red_own_goals.count, "red_score" => red_goals.count+blue_own_goals.count}

		#MyTable.where(["created_at < ?", 2.days.ago])

		return score
	end


	#the following methods have the potential to be moved into a decorator
	def is_finished
		if self.completed_at 
			true
		else
			false
		end
	end

	def is_in_progress
		if not self.completed_at 
			true
		else
			false
		end
	end

	#give player, returns true or false for if the player was on the winning team of the game
	def did_player_win?(player)
		winner_count = self.teams.winner.joins(:positions).where(:positions => {player_id: player.id}).count
		return winner_count > 0
	end


	#validators
	def teams_cannot_be_more_than_two
    errors[:base] = 'Games cannot have more than two teams' unless teams.size<=2
	end
	
# def game_cannot_be_started_without_two_teams
#		if started_at != nil and teams.size < 2 
#			errors[:base] = 'Games cannot be started without two teams' 
#		end
#	end
end
