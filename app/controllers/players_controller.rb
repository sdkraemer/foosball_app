class PlayersController < ApplicationController
  def new
  	@player = Player.new
  end

	def index
		@players = Player.all
	end

  def create
  	@player = Player.new(player_params).decorate
 
  	#if @player.save
		#	format.html { redirect_to edit_player_path(@player), notice: 'Player created successfully.' }
		#	format.json { render json: @player }
		#	format.js { render action: "show", status: :created, location: @player}
		#else
		#	format.html { redirect_to edit_player_path(@player), notice: 'Player created successfully.' }
		#end

		if @player.save
			flash[:notice] = "Player created."
			redirect_to edit_player_path(@player)
		else
			render :new
		end
	end

	def update
		@player = Player.find(params[:id])
		if @player.update(player_params)
			flash[:notice] = "Player saved."
			redirect_to edit_player_path(@player)
		else
			redirect_to edit_player_path(@player)
		end	
	end

	#need to move this logic into a helper or module to store statistics....or just a controller
  def edit
    @player = Player.find(params[:id]).decorate

    @games = GameDecorator.decorate_collection( Game.completed.distinct.joins(:teams).joins(:positions).where(:positions => {player_id: @player.id}).order(created_at: :desc).paginate(:page => params[:page], :per_page => 10) )
    game_ids = @games.map(&:id)

    @loser_ten = Team.distinct.loser.joins(:positions).where(:positions => {player_id: @player.id}, :teams => {game_id: game_ids}).count
    @winner_ten = Team.distinct.winner.joins(:positions).where(:positions => {player_id: @player.id}, :teams => {game_id: game_ids}).count
  end

  def show
  	@player = Player.find(params[:id])
  end

  private
	  def player_params
	    params.require(:player).permit(:username, :firstname, :lastname, :email)
	  end

end
