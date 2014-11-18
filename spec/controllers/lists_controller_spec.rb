require 'rails_helper'

RSpec.describe ListsController, :type => :controller do

  before(:each) do
    allow(controller).to receive(:must_be_logged_in)
    allow(controller).to receive(:must_be_list_owner)

    @user = User.create(uid: 1, access_token: "token", access_secret: "secret")

    allow(controller).to receive(:current_user).and_return(@user)
  end

  describe "#add" do
    it "assigns the lists to the list instance variable" do
      @list = List.create(name: "B", owner_id: 1337, block_list: [])

      allow(List).to receive(:of_friends).and_return([@list])

      get :add
      expect(assigns(:lists)).to eq([@list])
    end
  end

  describe "#create" do
    it "creates a list" do
      expect {
        post :create, list: { name: "List A", description: "Description A" }
      }.to change{ List.count }.by(1)
    end

    it "attaches the list to the current user" do
      expect {
        post :create, list: { name: "List A", description: "Description A" }
      }.to change{ @user.lists.count }.by(1)
    end

    it "has an owner_id equal to the current user's" do
      post :create, list: { name: "List A", description: "Description A" }

      list = List.where(name: "List A").first
      expect(list.owner_id).to equal @user.id
    end

    it "does not create a list when there's no name" do
      expect {
        post :create, list: { description: "Description A" }
      }.to_not change{ @user.lists.count }
    end

    it "renders new form when there's no name" do
      expect(post :create, list: { description: "Description A" }).to render_template(:new)
    end
  end

  describe "#destroy" do
    before(:each) do
      Troll.create(uid: 10)

      @list_a = List.create(name: "List A", owner_id: @user.id, block_list: [10])
      @user.lists << @list_a
    end

    it "deletes the list" do
      expect {
        delete :destroy, id: @list_a.id
      }.to change{ List.count }.by(-1)
    end

    it "calls unblock_multiple_trolls_for_multiple_users" do
      user_list = @list_a.user_list
      troll_list = @list_a.block_list

      allow(Blockqueue).to receive(:unblock_multiple_trolls_for_multiple_users)

      delete :destroy, id: @list_a.id

      expect(Blockqueue).to have_received(:unblock_multiple_trolls_for_multiple_users).with({ user_list: user_list, troll_list: troll_list })
    end
  end

  describe "#edit" do

    it "assigns the right list to the list variable" do
      @list = List.create(name: "B", owner_id: @user.id, block_list: [])

      get :edit, id: @list.id
      expect(assigns(:list)).to eq(@list)
    end
  end

  describe "#new" do
    it "assigns a new troll object to the list variable" do
      get :new
      expect(assigns(:list)).to be_a(List)
    end
  end

  describe "#subscribe" do
    before(:each) do
      Troll.create(uid: 10)
      Troll.create(uid: 20)
      Troll.create(uid: 30)
    end

    it "does not let a user who's only a follower subscribe" do
      @user_a = User.create(uid: 1, access_token: "token", access_secret: "secret", friend_list: [])
      @user_b = User.create(uid: 2, access_token: "token", access_secret: "secret", friend_list: [1])
      allow(controller).to receive(:current_user).and_return(@user_b)

      @list_a = List.create(name: "List A", owner_id: @user_a.id)

      expect {
        post :subscribe, list_id: @list_a.id
      }.to_not change{ @list_a.users.count }
    end

    it "does not let a user who's only being followed subscribe" do
      @user_a = User.create(uid: 1, access_token: "token", access_secret: "secret", friend_list: [2])
      @user_b = User.create(uid: 2, access_token: "token", access_secret: "secret", friend_list: [])
      allow(controller).to receive(:current_user).and_return(@user_b)

      @list_a = List.create(name: "List A", owner_id: @user_a.id)

      expect {
        post :subscribe, list_id: @list_a.id
      }.to_not change{ @list_a.users.count }
    end

    it "lets a user who's a mutual friend subscribe" do
      @user_a = User.create(uid: 1, access_token: "token", access_secret: "secret", friend_list: [2])
      @user_b = User.create(uid: 2, access_token: "token", access_secret: "secret", friend_list: [1])
      allow(controller).to receive(:current_user).and_return(@user_b)

      @list_a = List.create(name: "List A", owner_id: @user_a.id, block_list: [10,20,30])

      expect {
        post :subscribe, list_id: @list_a.id
      }.to change{ @list_a.users.count }
    end

    it "calls block_multiple_trolls_for_single_user when a user who's a mutual friend subscribes" do
      @user_a = User.create(uid: 1, access_token: "token", access_secret: "secret", friend_list: [2])
      @user_b = User.create(uid: 2, access_token: "token", access_secret: "secret", friend_list: [1])
      allow(controller).to receive(:current_user).and_return(@user_b)

      @list_a = List.create(name: "List A", owner_id: @user_a.id, block_list: [10,20,30])

      allow(Blockqueue).to receive(:block_multiple_trolls_for_single_user)

      post :subscribe, list_id: @list_a.id

      expect(Blockqueue).to have_received(:block_multiple_trolls_for_single_user).with({ list: [10,20,30], user: @user_b })
    end
  end

  describe "#unsubscribe" do

    before(:each) do
      @user_a = User.create(uid: 1, access_token: "token", access_secret: "secret", friend_list: [2])
      @user_b = User.create(uid: 2, access_token: "token", access_secret: "secret", friend_list: [1])
      allow(controller).to receive(:current_user).and_return(@user_b)

      @list_a = List.create(name: "List A", owner_id: @user_a.id, block_list: [10,20,30])
      @user_b.lists << @list_a

      @troll_a = Troll.create(uid: 10)
      @troll_b = Troll.create(uid: 20)
      @troll_c = Troll.create(uid: 30)
    end

    it "lets a user who's subscribed to a list unsubscribe" do
      expect {
        delete :unsubscribe, list_id: @list_a.id
      }.to change{ @list_a.users.count }.by(-1)
    end

    it "calls unblock_multiple_trolls_for_single_user when a user unsubscribes" do
      allow(Blockqueue).to receive(:unblock_multiple_trolls_for_single_user)

      delete :unsubscribe, list_id: @list_a.id

      expect(Blockqueue).to have_received(:unblock_multiple_trolls_for_single_user).with({ list: [10,20,30], user: @user_b })
    end

  end

  describe "#update" do

    it "adds new blocks to the list's block_list" do
      @list_a = List.create(name: "List A", owner_id: @user.id)
      @troll_a = Troll.create(uid: 10)
      @troll_b = Troll.create(uid: 20)
      @troll_c = Troll.create(uid: 30)

      expect {
        patch :update, id: @list_a, list: { troll_ids: [10, 20] }
        @list_a.reload
      }.to change{ @list_a.block_list }.to eq([10,20])
    end

    it "removes old blocks from the list's block_list" do
      @list_a = List.create(name: "List A", owner_id: @user.id, block_list: [10, 20, 30])
      @troll_a = Troll.create(uid: 10)
      @troll_b = Troll.create(uid: 20)
      @troll_c = Troll.create(uid: 30)

      expect {
        patch :update, id: @list_a, list: { troll_ids: ["10", "20"] }
        @list_a.reload
      }.to change{ @list_a.block_list }.to eq([10,20])
    end

    it "adds auto-add when appropriate" do
      @list_a = List.create(name: "List A", owner_id: @user.id)

      expect {
        patch :update, id: @list_a, list: { troll_ids: [""], auto_add_new_blocks: "1" }
        @list_a.reload
      }.to change{ @list_a.auto_add_new_blocks }.to be true
    end

    it "removes auto-add when appropriate" do
      @list_a = List.create(name: "List A", owner_id: @user.id, auto_add_new_blocks: true)

      expect {
        patch :update, id: @list_a, list: { troll_ids: [""] }
        @list_a.reload
      }.to change{ @list_a.auto_add_new_blocks }.to be false
    end

    it "updates the name and description when appropriate" do
      @list_a = List.create(name: "List A", description: "Hey hey", owner_id: @user.id, auto_add_new_blocks: false)

      expect {
        patch :update, id: @list_a, list: { name: "New name", description: "New description", troll_ids: [""], auto_add_new_blocks: "0" }
        @list_a.reload
      }.to change{ @list_a.name }.to eq("New name")
      expect(@list_a.description).to eq("New description")
    end

    it "does not call the blockqueue with added block work if list is only followed by its owner" do
      @list_a = @user.lists.create(name: "List A", description: "Hey hey", owner_id: @user.id)
      @troll_a = Troll.create(uid: 10)

      allow(Blockqueue).to receive(:block_multiple_trolls_for_multiple_users)

      patch :update, id: @list_a, list: { name: "New name", description: "New description", troll_ids: ["10"] }
      @list_a.reload

      expect(Blockqueue).to_not have_received(:block_multiple_trolls_for_multiple_users)
    end

    it "calls the blockqueue with added block work if list is followed by another" do
      @user_b = User.create(uid: 2, access_token: "token", access_secret: "secret")

      @list_a = @user.lists.create(name: "List A", description: "Hey hey", owner_id: @user.id)
      @user_b.lists << @list_a
      @troll_a = Troll.create(uid: 10)

      allow(Blockqueue).to receive(:block_multiple_trolls_for_multiple_users)

      patch :update, id: @list_a, list: { name: "New name", description: "New description", troll_ids: ["10"] }
      @list_a.reload

      expect(Blockqueue).to have_received(:block_multiple_trolls_for_multiple_users).with({ troll_list: [@troll_a.uid], user_list: @list_a.user_list })
    end

    it "does not call the blockqueue with removed block work if list is only followed by its owner" do
      @user_b = User.create(uid: 2, access_token: "token", access_secret: "secret")

      @list_a = @user.lists.create(name: "List A", description: "Hey hey", owner_id: @user.id, block_list: [10])
      @troll_a = Troll.create(uid: 10)

      allow(Blockqueue).to receive(:unblock_multiple_trolls_for_multiple_users)

      patch :update, id: @list_a, list: { name: "New name", description: "New description", troll_ids: [""] }
      @list_a.reload

      expect(Blockqueue).to_not have_received(:unblock_multiple_trolls_for_multiple_users)
    end

    it "calls the blockqueue with removed block work if list is followed by another" do
      @user_b = User.create(uid: 2, access_token: "token", access_secret: "secret")

      @list_a = @user.lists.create(name: "List A", description: "Hey hey", owner_id: @user.id, block_list: [10])
      @user_b.lists << @list_a
      @troll_a = Troll.create(uid: 10)

      allow(Blockqueue).to receive(:unblock_multiple_trolls_for_multiple_users)

      patch :update, id: @list_a, list: { name: "New name", description: "New description", troll_ids: [""] }
      @list_a.reload

      expect(Blockqueue).to have_received(:unblock_multiple_trolls_for_multiple_users).with({ troll_list: [@troll_a.uid], user_list: @list_a.user_list })
    end

    it "renders edit template if list has no name" do
      @list_a = @user.lists.create(name: "List A", description: "Hey hey", owner_id: @user.id, block_list: [10])

      expect(patch :update, id: @list_a, list: { name: "", description: "Whatever", troll_ids: [""] }).to render_template(:edit)
    end
  end
end
