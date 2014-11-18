require 'rails_helper'

RSpec.describe User, :type => :model do

  describe "#created_lists" do
    it "returns lists where user is the owner" do
      @user = User.create(access_token: "token", access_secret: "secret")
      @list_a = List.create(name: "A", owner_id: @user.id, block_list: [10, 20, 30])
      @list_b = List.create(name: "B", owner_id: 1337, block_list: [40, 50, 60])
      @user.lists << @list_a
      @user.lists << @list_b

      expect(@user.created_lists).to eq([@list_a])
    end
  end

  describe "#subscribed_lists" do
    it "returns lists where user is not the owner" do
      @user = User.create(access_token: "token", access_secret: "secret")
      @list_a = List.create(name: "A", owner_id: @user.id, block_list: [10, 20, 30])
      @list_b = List.create(name: "B", owner_id: 1337, block_list: [40, 50, 60])
      @user.lists << @list_a
      @user.lists << @list_b

      expect(@user.subscribed_lists).to eq([@list_b])
    end
  end

  describe "#no_email?" do
    it "returns false if declined is true" do
      @user = User.new(access_token: "token", access_secret: "secret", declined: true)
      expect(@user.no_email?).to be false
    end

    it "returns false if email is present" do
      @user = User.new(access_token: "token", access_secret: "secret", email: "whatever@me.com")
      expect(@user.no_email?).to be false
    end

    it "returns true if no email and not declined" do
      @user = User.new(access_token: "token", access_secret: "secret")
      expect(@user.no_email?).to be true
    end
  end

  describe "#own_trolls" do
    it "returns an array of the user's own_blocks, as trolls" do
      @user = User.create(access_token: "token", access_secret: "secret", own_blocks: [10, 20])
      @a = Troll.create(uid: 10)
      @b = Troll.create(uid: 20)

      expect(@user.own_trolls).to eq([@a, @b])
    end
  end

  describe "#has_list_with_block?" do
    before(:each) do
      @user = User.create(access_token: "token", access_secret: "secret")
      @user.lists << List.create(name: "A", block_list: [10, 20, 30])
      @user.lists << List.create(name: "B", block_list: [40, 50, 60])
      @user.lists << List.create(name: "C", block_list: [70, 80, 90])
    end

    it "returns true when the user has a list with that ID in it" do
      @troll = Troll.create(uid: 50)

      expect(@user.has_list_with_block?(troll: @troll)).to be true
    end

    it "returns false when the user does not have a list with that ID in it" do
      @troll = Troll.create(uid: 100)

      expect(@user.has_list_with_block?(troll: @troll)).to be false
    end

    it "returns true when the user's own_blocks has that ID in it" do
      @user.own_blocks = [110]
      @user.save
      @troll = Troll.create(uid: 110)

      expect(@user.has_list_with_block?(troll: @troll)).to be true
    end
  end

  describe "#initialize_blocks" do
    before(:each) do
      allow(Troll).to receive(:create_troll)
      allow(Troll).to receive(:initialize_troll)
    end

    it "calls Troll.create_troll once for each blocked user" do
      user = User.create(access_token: "token", access_secret: "secret")

      user.initialize_blocks
      expect(Troll).to have_received(:create_troll).thrice
    end

    it "starts calling Troll.initialize_troll if there's more than 100 blocked users" do
      user = User.create(access_token: "long_block_list", access_secret: "secret")

      user.initialize_blocks
      expect(Troll).to have_received(:create_troll).exactly(100).times
      expect(Troll).to have_received(:initialize_troll).exactly(25).times
    end

    it "sets the oversized flag to true if we get a too many requests error" do
      user = User.create(access_token: "too_many_requests", access_secret: "secret")

      user.initialize_blocks
      expect(user.oversized).to be true
      expect(Troll).to_not have_received(:create_troll)
      expect(Troll).to_not have_received(:initialize_troll)
    end

    it "initializes blocks with the initialize_blocks method" do
      user = User.create(access_token: "token", access_secret: "secret")

      expect {
        user.initialize_blocks
      }.to change { user.block_list }.to([1001,1002,1003])
    end

    it "initializes own_blocks with the initialize_blocks method" do
      user = User.create(access_token: "token", access_secret: "secret")

      expect {
        user.initialize_blocks
      }.to change { user.own_blocks }.to([1001,1002,1003])
    end
  end

  describe "#initialize_friends" do
    it "initializes friends with the initialize_friends method" do
      user = User.create(access_token: "token", access_secret: "secret")
      expect {
        user.initialize_friends
        user.reload
      }.to change { user.friend_list }.to([100,200,300,400,500,600,700,800,900,1000])
    end

    it "sets the oversized flag to true if we get a too many requests error" do
      user = User.create(access_token: "too_many_requests", access_secret: "secret")

      expect {
        user.initialize_friends
      }.to change { user.oversized }.to be true
    end
  end

  describe "#mutual_friends" do
    it "finds only mutual friends" do
      user_1 = User.create(access_token: "token", access_secret: "secret", uid: 1, friend_list: [2,3])
      user_2 = User.create(access_token: "token", access_secret: "secret", uid: 2, friend_list: [1,3])
      user_3 = User.create(access_token: "token", access_secret: "secret", uid: 3)

      expect(user_1.mutual_friends).to eq([user_2])
    end
  end

  describe "#refresh_friends" do
    # all refresh friends examples are fetching this new friends list:
    # [100,200,300,400,500,600,700,800,900,1000]

    before(:each) do
      # stub out the Blockqueue calls here
      allow(Blockqueue).to receive(:block_troll)
      allow(Blockqueue).to receive(:unblock_multiple_trolls_for_single_user)
    end

    it "should add a new friend to a user's friend_list" do
      user = User.create(access_token: "token", access_secret: "secret", friend_list: [100,200,300,400,500])
      expect {
        user.refresh_friends
        user.reload
      }.to change{ user.friend_list }.to([100,200,300,400,500,600,700,800,900,1000])
    end

    it "should take a removed friend off a user's friend_list" do
      user = User.create(access_token: "token", access_secret: "secret", friend_list: [100,200,300,400,500,600,700,800,900,1000,1100,1200])
      expect {
        user.refresh_friends
        user.reload
      }.to change{ user.friend_list }.to([100,200,300,400,500,600,700,800,900,1000])
    end

    it "should add to blockqueue when a friend is removed and they're also a troll" do
      user = User.create(access_token: "token", access_secret: "secret", friend_list: [1100,1200], block_list: [])
      other = User.create(access_token: "token", access_secret: "secret")
      troll = Troll.create(uid: 1100)

      # three lists should still only generate one block
      user.lists.create(name: "W", owner_id: other.id, block_list: [1100])
      user.lists.create(name: "X", owner_id: other.id, block_list: [1100])
      user.lists.create(name: "Y", owner_id: other.id, block_list: [1100])

      user.refresh_friends

      expect {
        user.refresh_friends
        user.reload
      }.to_not change{ user.block_list }
      expect(Blockqueue).to have_received(:block_troll).with(troll: troll, user: user).once
    end

    it "should remove lists and add to blockqueue when mutual friend relationships are broken" do

      # N.B. Had an impossible time trying to just mock wipe_removed_friends_lists for user
      # and friend and then check the number of calls to it. Still don't know why but you
      # can only debug an rspec test for so long...

      user = User.create(uid: 1200, access_token: "token", access_secret: "secret", friend_list: [1100])
      friend = User.create(uid: 1100, access_token: "token", access_secret: "secret", friend_list: [1200])

      user.lists.create(name: "X", owner_id: friend.id, block_list: [10,20,30])
      friend.lists.create(name: "Y", owner_id: user.id, block_list: [40,50,60])

      allow(Blockqueue).to receive(:unblock_multiple_trolls_for_single_user)

      expect(user.lists.where(owner_id: friend.id).count).to eq(1)
      expect(friend.lists.where(owner_id: user.id).count).to eq(1)

      user.refresh_friends

      expect(user.lists.where(owner_id: friend.id).count).to eq(0)
      expect(friend.lists.where(owner_id: user.id).count).to eq(0)

      expect(Blockqueue).to have_received(:unblock_multiple_trolls_for_single_user).twice
      expect(Blockqueue).to have_received(:unblock_multiple_trolls_for_single_user).with(list: [10,20,30], user: user).once
      expect(Blockqueue).to have_received(:unblock_multiple_trolls_for_single_user).with(list: [40,50,60], user: friend).once
    end

    it "should delete access_token and access_secret if user not authorized" do
      user = User.create(access_token: "not_authorized", access_secret: "secret")
      user.refresh_friends
      user.reload
      expect(user.access_token).to eq('')
      expect(user.access_secret).to eq('')
    end

    it "sets the oversized flag to true if we get a too many requests error" do
      user = User.create(access_token: "too_many_requests", access_secret: "secret")

      expect {
        user.refresh_friends
      }.to change { user.oversized }.to be true
    end
  end

  describe "#refresh_blocks" do
    # refresh blocks grabs blocks_ids which normally returns [1001,1002,1003]

    before(:each) do
      allow(Troll).to receive(:initialize_troll)
      allow(Blockqueue).to receive(:block_multiple_trolls_for_multiple_users)
      allow(Blockqueue).to receive(:unblock_multiple_trolls_for_multiple_users)
    end

    it "should add a new block to a user's block list" do
      user = User.create(access_token: "token", access_secret: "secret", block_list: [1001], own_blocks: [1001])

      expect {
        user.refresh_blocks
      }.to change { user.block_list }.to eq([1001,1002,1003])
    end

    it "should call Troll.initialize_troll once for each new block" do
      user = User.create(access_token: "token", access_secret: "secret", block_list: [1001], own_blocks: [1001])

      user.refresh_blocks
      expect(Troll).to have_received(:initialize_troll).twice
      expect(Troll).to have_received(:initialize_troll).with(twitter_id: 1002).once
      expect(Troll).to have_received(:initialize_troll).with(twitter_id: 1003).once
    end

    it "should not add a new block on a subscribed list to a user's own blocks" do
      user = User.create(access_token: "token", access_secret: "secret", block_list: [1001], own_blocks: [1001])
      user.lists.create(name: "A", owner_id: 1337, block_list: [1002, 1003])

      expect {
        user.refresh_blocks
      }.to_not change { user.own_blocks }
    end

    it "should add a new block not on a subscribed list to a user's own blocks" do
      user = User.create(access_token: "token", access_secret: "secret", block_list: [1001], own_blocks: [1001])

      expect {
        user.refresh_blocks
      }.to change { user.own_blocks }.to([1001,1002,1003])
    end

    it "should add the new blocks to each list auto-subscribed to new blocks" do
      user = User.create(access_token: "token", access_secret: "secret", block_list: [1001], own_blocks: [1001])
      list_a = user.lists.create(name: "A", owner_id: user.id, block_list: [1001], auto_add_new_blocks: true)
      list_b = user.lists.create(name: "B", owner_id: user.id, block_list: [1001], auto_add_new_blocks: true)
      list_c = user.lists.create(name: "C", owner_id: user.id, block_list: [1001], auto_add_new_blocks: false)

      user.refresh_blocks

      list_a.reload
      list_b.reload
      list_c.reload

      expect(list_a.block_list).to eq([1001,1002,1003])
      expect(list_b.block_list).to eq([1001,1002,1003])
      expect(list_c.block_list).to eq([1001])
    end

    it "should call the blockqueue for the users subscribed to a list with new blocks" do
      user = User.create(uid: 1, access_token: "token", access_secret: "secret", block_list: [1001], own_blocks: [1001])
      list_a = user.lists.create(name: "A", owner_id: user.id, block_list: [1001], auto_add_new_blocks: true)
      list_b = user.lists.create(name: "B", owner_id: user.id, block_list: [1001], auto_add_new_blocks: true)
      list_c = user.lists.create(name: "B", owner_id: user.id, block_list: [1001], auto_add_new_blocks: false)

      follower_a = User.create(uid: 2, access_token: "token", access_secret: "secret", block_list: [1001])
      follower_a.lists << list_a
      follower_a.lists << list_c

      follower_b = User.create(uid: 3, access_token: "token", access_secret: "secret", block_list: [1001])
      follower_b.lists << list_a

      follower_c = User.create(uid: 4, access_token: "token", access_secret: "secret", block_list: [1001])
      follower_c.lists << list_b

      follower_d = User.create(uid: 5, access_token: "token", access_secret: "secret", block_list: [1001])
      follower_d.lists << list_b

      user.refresh_blocks

      expect(Blockqueue).to have_received(:block_multiple_trolls_for_multiple_users).twice
      expect(Blockqueue).to have_received(:block_multiple_trolls_for_multiple_users).with(user_list: [2,3], troll_list: [1002,1003]).once
      expect(Blockqueue).to have_received(:block_multiple_trolls_for_multiple_users).with(user_list: [4,5], troll_list: [1002,1003]).once
    end

    it "should remove a removed block from a user's block list" do
      user = User.create(access_token: "token", access_secret: "secret", block_list: [1001,1002,1003,1004], own_blocks: [1001,1002,1003,1004])

      expect {
        user.refresh_blocks
      }.to change { user.block_list }.to eq([1001,1002,1003])
    end

    it "should remove a removed block from the user's own_blocks" do
      user = User.create(access_token: "token", access_secret: "secret", block_list: [1001,1002,1003,1004], own_blocks: [1001,1002,1003,1004])

      expect {
        user.refresh_blocks
      }.to change { user.own_blocks }.to([1001,1002,1003])
    end

    it "should remove a removed block from every list the user owns" do
      user = User.create(access_token: "token", access_secret: "secret", block_list: [1001,1002,1003,1004], own_blocks: [1001,1002,1003,1004])

      list_a = user.lists.create(name: "A", owner_id: user.id, block_list: [1001,1002,1004])
      list_b = user.lists.create(name: "B", owner_id: user.id, block_list: [1001,1003,1004])

      user.refresh_blocks

      list_a.reload
      list_b.reload

      expect(list_a.block_list).to eq([1001,1002])
      expect(list_b.block_list).to eq([1001,1003])
    end

    it "should call the blockqueue for the users subscribed to a list with removed blocks" do
      user = User.create(uid: 1, access_token: "token", access_secret: "secret", block_list: [1001,1002,1003,1004,1005], own_blocks: [1001,1002,1003,1004,1005])
      list_a = user.lists.create(name: "A", owner_id: user.id, block_list: [1001,1004,1005])
      list_b = user.lists.create(name: "B", owner_id: user.id, block_list: [1003,1004,1005])
      list_c = user.lists.create(name: "B", owner_id: user.id, block_list: [1001,1002,1003])

      follower_a = User.create(uid: 2, access_token: "token", access_secret: "secret", block_list: [1001,1002,1003,1004,1005])
      follower_a.lists << list_a
      follower_a.lists << list_c

      follower_b = User.create(uid: 3, access_token: "token", access_secret: "secret", block_list: [1001,1002,1003,1004,1005])
      follower_b.lists << list_a

      follower_c = User.create(uid: 4, access_token: "token", access_secret: "secret", block_list: [1001,1002,1003,1004,1005])
      follower_c.lists << list_b

      follower_d = User.create(uid: 5, access_token: "token", access_secret: "secret", block_list: [1001,1002,1003,1004,1005])
      follower_d.lists << list_b

      user.refresh_blocks

      expect(Blockqueue).to have_received(:unblock_multiple_trolls_for_multiple_users).twice
      expect(Blockqueue).to have_received(:unblock_multiple_trolls_for_multiple_users).with(user_list: [2,3], troll_list: [1004,1005]).once
      expect(Blockqueue).to have_received(:unblock_multiple_trolls_for_multiple_users).with(user_list: [4,5], troll_list: [1004,1005]).once
    end

    it "should delete access_token and access_secret if user not authorized" do
      user = User.create(access_token: "not_authorized", access_secret: "secret")
      user.refresh_blocks
      user.reload
      expect(user.access_token).to eq('')
      expect(user.access_secret).to eq('')
    end

    it "sets the oversized flag to true if we get a too many requests error" do
      user = User.create(access_token: "too_many_requests", access_secret: "secret")

      expect {
        user.refresh_blocks
      }.to change { user.oversized }.to be true
    end
  end

  describe "#wipe_removed_friends_lists" do
    before(:each) do
      allow(Blockqueue).to receive(:unblock_multiple_trolls_for_single_user)
      @user = User.create(uid: 1, access_token: "token", access_secret: "secret")
      @friend = User.create(uid: 2, access_token: "token", access_secret: "secret")

      @user.lists.create(name: "A", owner_id: @friend.id, block_list: [10,20,30])
      @user.lists.create(name: "B", owner_id: @friend.id, block_list: [40,50,60])
      @user.lists.create(name: "C", owner_id: 1337, block_list: [70,80,90])
    end

    it "should call out to Blockqueue once for each list owned by the friend" do
      @user.wipe_removed_friends_lists(friend: @friend)
      expect(Blockqueue).to have_received(:unblock_multiple_trolls_for_single_user).twice
      expect(Blockqueue).to have_received(:unblock_multiple_trolls_for_single_user).with(user: @user, list: [10,20,30])
      expect(Blockqueue).to have_received(:unblock_multiple_trolls_for_single_user).with(user: @user, list: [40,50,60])
    end
  end
end
