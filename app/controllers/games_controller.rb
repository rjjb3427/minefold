class GamesController < ApplicationController

  expose(:game) {
    GAMES.find(params[:id])
  }

  def show
    @popular_funpacks = Funpack.order(:name).where(game_id: game.id).reject {|funpack| funpack.id == game.funpack_id }
  end

end
