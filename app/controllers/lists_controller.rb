class ListsController < ApplicationController

  # order of operations:

  # if needed, the list is created
  # if needed, the user is always added to or removed from a list
  # then and only then is the block_list in that list processed
  # if needed, the list is destroyed

  before_filter :must_be_logged_in, only: [ :index, :new, :create, :edit, :update, :destroy, :add, :subscribe, :unsubscribe]

  before_filter :must_be_list_owner, only: [ :edit, :update, :destroy ]

  def add
    @lists = List.of_friends(current_user)
  end

  def create
    @list = List.new(list_params)
    @list.owner_id = current_user.id
    @list.block_list = []

    if @list.save
      current_user.lists << @list
      flash[:success] = "Your list named '#{@list.name}' has been created!"
      redirect_to edit_list_path(@list)
    else
      render 'new'
    end
  end

  def destroy
    list = current_user.lists.where(id: params[:id], owner_id: current_user.id).first

    troll_list = list.block_list
    user_list  = list.user_list

    list.users.each { |u| u.lists.delete(list) }

    Blockqueue.unblock_multiple_trolls_for_multiple_users(user_list: user_list, troll_list: troll_list)

    list_name = list.name
    list.destroy!

    flash[:success] = "You've destroyed '#{list_name}' - it'll no longer appear in your account"
    redirect_to lists_path
  end

  def edit
    @list = List.where(id: params[:id], owner_id: current_user.id).first
  end

  def index
  end

  def new
    @list = List.new
  end

  def subscribe
    list = List.where(id: params[:list_id]).first

    unless (current_user.mutual_friend? list.owner)
      flash[:error] = "Sorry, but I don't think you're supposed to be there."
      redirect_to lists_path and return
    end

    current_user.lists << list

    Blockqueue.block_multiple_trolls_for_single_user(list: list.block_list, user: current_user)

    flash[:success] = "You're now subscribed to '#{list.name}' - we'll start blocking those losers for you."
    redirect_to lists_path
  end

  def update
    @list = List.where(id: params[:id], owner_id: current_user.id).first

    @list.name = params[:list][:name] if params[:list][:name]
    @list.description = params[:list][:description] if params[:list][:description]

    if params[:list][:auto_add_new_blocks] == "1"
      @list.auto_add_new_blocks = true
    else
      @list.auto_add_new_blocks = false
    end

    if params[:list][:troll_ids]
      new_array = params[:list][:troll_ids].reject(&:empty?).map { |x| x.to_i }

      added_trolls = new_array - @list.block_list
      removed_trolls = @list.block_list - new_array

      @list.block_list = new_array
    end

    if @list.save

      if @list.users.count > 1
        Blockqueue.block_multiple_trolls_for_multiple_users(troll_list: added_trolls, user_list: @list.user_list)
        Blockqueue.unblock_multiple_trolls_for_multiple_users(troll_list: removed_trolls, user_list: @list.user_list)
      end

      flash[:success] = "Your '#{@list.name}' list has been updated!"
      redirect_to lists_path
    else
      render 'edit'
    end
  end

  def unsubscribe
    list = List.where(id: params[:list_id]).first
    current_user.lists.delete(list)

    Blockqueue.unblock_multiple_trolls_for_single_user(list: list.block_list, user: current_user)

    flash[:success] = "You're no longer subscribed to '#{list.name}' - we'll gradually unblock those accounts."
    redirect_to lists_path
  end

  private

  def list_params
    params.require(:list).permit(:name, :description, troll_ids: [])
  end

end
