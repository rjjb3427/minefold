class ServersController < ApplicationController
  respond_to :html

  prepend_before_filter :authenticate_user!, :except => [:show, :map]

# --

  expose(:server)

# --

  def index
    @servers = current_user.servers.all.group_by {|s| s.funpack.game }
  end

  def new
    authorize! :create, server
    
    @games = Game.all
    # TODO replace with actual data in Javascript
    @funpack = Funpack.first
  end
  
  def new_funpack_settings
    authorize! :create, server
    
    @funpack = Funpack.find(params[:funpack_id])
    
    render layout: false
  end

  def create
    authorize! :create, server
    
    server.creator = current_user
    server.users << current_user

    server.save
    respond_with(server)
  end

  def show
  end
  
  def map
    not_found unless server.funpack.game.minecraft?
  end

  def edit
    authorize! :update, server
  end

  def update
    authorize! :update, server
    server.update_attributes(params[:server])
    respond_with(server)
  end

  def destroy
    authorize! :destroy, server
    
    server.destroy
    
    redirect_to(servers_path, notice: "Server \"#{server.name}\" was destroyed.")
  end

end
