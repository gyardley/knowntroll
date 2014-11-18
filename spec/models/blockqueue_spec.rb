require 'rails_helper'

RSpec.describe Blockqueue, :type => :model do

  describe "#block_troll" do
    before(:each) do
      @troll = Troll.create(uid: 10)
    end

    it "removes existing unblock tasks for that user and troll" do
      @user = User.create(uid: 1, access_token: "token", access_secret: "secret", block_list: [10])

      Blockqueue.create(task: :unblock, user: @user, troll: @troll)

      expect {
        Blockqueue.block_troll(user: @user, troll: @troll)
      }.to change{ Blockqueue.count }.by(-1)
    end

    it "if the troll is a friend, it does not create a block task" do
      @user = User.create(uid: 1, access_token: "token", access_secret: "secret", friend_list: [10])

      expect {
        Blockqueue.block_troll(user: @user, troll: @troll)
      }.to_not change{ Blockqueue.count }
    end

    it "if the troll has not yet been blocked, it creates a block task" do
      @user = User.create(uid: 1, access_token: "token", access_secret: "secret")

      expect {
        Blockqueue.block_troll(user: @user, troll: @troll)
      }.to change{ Blockqueue.count }.by(1)
    end

    it "if the troll is already blocked, it does not create a block task" do
      @user = User.create(uid: 1, access_token: "token", access_secret: "secret", block_list: [10])

      expect {
        Blockqueue.block_troll(user: @user, troll: @troll)
      }.to_not change{ Blockqueue.count }
    end
  end

  describe "#unblock_troll" do
    before(:each) do
      @troll = Troll.create(uid: 10)
    end

    it "removes existing block tasks for that account and troll" do
      @user = User.create(uid: 1, access_token: "token", access_secret: "secret", block_list: [10])

      Blockqueue.create(task: :block, user: @user, troll: @troll)

      Blockqueue.unblock_troll(user: @user, troll: @troll)
      expect(Blockqueue.where(task: Blockqueue.tasks[:block], user: @user, troll: @troll).count).to eq(0)
    end

    it "if the troll is not blocked by a user's list, it creates an unblock task" do
      @user = User.create(uid: 1, access_token: "token", access_secret: "secret", block_list: [10], own_blocks: [20, 30])
      @user.lists << List.create(name: "A", block_list: [40, 50])

      expect {
        Blockqueue.unblock_troll(user: @user, troll: @troll)
      }.to change{ Blockqueue.count }.by(1)
      expect(Blockqueue.where(task: Blockqueue.tasks[:unblock], user: @user, troll: @troll).count).to eq(1)
    end

    it "if the troll is blocked by a user's list, it does not create an unblock task" do
      @user = User.create(uid: 1, access_token: "token", access_secret: "secret", block_list: [10], own_blocks: [20, 30])
      @user.lists << List.create(name: "A", block_list: [10, 40, 50])

      Blockqueue.unblock_troll(user: @user, troll: @troll)
      expect(Blockqueue.where(task: Blockqueue.tasks[:unblock], user: @user, troll: @troll).count).to eq(0)
    end

    it "if the troll is in a user's own blocks, it does not create an unblock task" do
      @user = User.create(uid: 1, access_token: "token", access_secret: "secret", block_list: [10], own_blocks: [10, 20, 30])
      @user.lists << List.create(name: "A", block_list: [40, 50])

      Blockqueue.unblock_troll(user: @user, troll: @troll)
      expect(Blockqueue.where(task: Blockqueue.tasks[:unblock], user: @user, troll: @troll).count).to eq(0)
    end
  end

  describe "#block_multiple_trolls_for_single_user" do
    before(:each) do
      allow(Blockqueue).to receive(:block_troll)
    end

    it "calls block_troll once for each entry in the list" do
      @user = User.create(uid: 1, access_token: "token", access_secret: "secret")
      @troll_10 = Troll.create(uid: 10)
      @troll_20 = Troll.create(uid: 20)
      @troll_30 = Troll.create(uid: 30)

      Blockqueue.block_multiple_trolls_for_single_user(user: @user, list: [10,20,30])

      expect(Blockqueue).to have_received(:block_troll).thrice
      expect(Blockqueue).to have_received(:block_troll).with(user: @user, troll: @troll_10).once
      expect(Blockqueue).to have_received(:block_troll).with(user: @user, troll: @troll_20).once
      expect(Blockqueue).to have_received(:block_troll).with(user: @user, troll: @troll_30).once
    end
  end

  describe "#unblock_multiple_trolls_for_single_user" do
    before(:each) do
      allow(Blockqueue).to receive(:unblock_troll)
    end

    it "calls unblock_troll once for each entry in the list" do
      @user = User.create(uid: 1, access_token: "token", access_secret: "secret", block_list: [10,20,30])
      @troll_10 = Troll.create(uid: 10)
      @troll_20 = Troll.create(uid: 20)
      @troll_30 = Troll.create(uid: 30)

      Blockqueue.unblock_multiple_trolls_for_single_user(user: @user, list: [10,20,30])

      expect(Blockqueue).to have_received(:unblock_troll).thrice
      expect(Blockqueue).to have_received(:unblock_troll).with(user: @user, troll: @troll_10).once
      expect(Blockqueue).to have_received(:unblock_troll).with(user: @user, troll: @troll_20).once
      expect(Blockqueue).to have_received(:unblock_troll).with(user: @user, troll: @troll_30).once
    end
  end

  describe "#block_single_troll_for_multiple_users" do
    before(:each) do
      allow(Blockqueue).to receive(:block_troll)
    end

    it "calls block_troll once for each entry in the list" do
      @user_1 = User.create(uid: 1, access_token: "token", access_secret: "secret")
      @user_2 = User.create(uid: 2, access_token: "token", access_secret: "secret")
      @user_3 = User.create(uid: 3, access_token: "token", access_secret: "secret")
      @troll = Troll.create(uid: 10)

      Blockqueue.block_single_troll_for_multiple_users(troll: @troll, list: [1,2,3])

      expect(Blockqueue).to have_received(:block_troll).thrice
      expect(Blockqueue).to have_received(:block_troll).with(user: @user_1, troll: @troll).once
      expect(Blockqueue).to have_received(:block_troll).with(user: @user_2, troll: @troll).once
      expect(Blockqueue).to have_received(:block_troll).with(user: @user_3, troll: @troll).once
    end
  end

  describe "#unblock_single_troll_for_multiple_users" do
    before(:each) do
      allow(Blockqueue).to receive(:unblock_troll)
    end

    it "calls unblock_troll once for each entry in the list" do
      @user_1 = User.create(uid: 1, access_token: "token", access_secret: "secret")
      @user_2 = User.create(uid: 2, access_token: "token", access_secret: "secret")
      @user_3 = User.create(uid: 3, access_token: "token", access_secret: "secret")
      @troll = Troll.create(uid: 10)

      Blockqueue.unblock_single_troll_for_multiple_users(troll: @troll, list: [1,2,3])

      expect(Blockqueue).to have_received(:unblock_troll).thrice
      expect(Blockqueue).to have_received(:unblock_troll).with(user: @user_1, troll: @troll).once
      expect(Blockqueue).to have_received(:unblock_troll).with(user: @user_2, troll: @troll).once
      expect(Blockqueue).to have_received(:unblock_troll).with(user: @user_3, troll: @troll).once
    end
  end

  describe "#block_multiple_trolls_for_multiple_users" do
    before(:each) do
      allow(Blockqueue).to receive(:block_troll)
    end

    it "calls block_troll once for each troll on the list, for each person on the list" do
      @user_1 = User.create(uid: 1, access_token: "token", access_secret: "secret")
      @user_2 = User.create(uid: 2, access_token: "token", access_secret: "secret")
      @troll_10 = Troll.create(uid: 10)
      @troll_20 = Troll.create(uid: 20)

      Blockqueue.block_multiple_trolls_for_multiple_users(troll_list: [10,20], user_list: [1,2])

      expect(Blockqueue).to have_received(:block_troll).exactly(4).times
      expect(Blockqueue).to have_received(:block_troll).with(user: @user_1, troll: @troll_10).once
      expect(Blockqueue).to have_received(:block_troll).with(user: @user_1, troll: @troll_20).once
      expect(Blockqueue).to have_received(:block_troll).with(user: @user_2, troll: @troll_10).once
      expect(Blockqueue).to have_received(:block_troll).with(user: @user_2, troll: @troll_20).once
    end
  end

  describe "#unblock_multiple_trolls_for_multiple_users" do
    before(:each) do
      allow(Blockqueue).to receive(:unblock_troll)
    end

    it "calls unblock_troll once for each troll on the list, for each person on the list" do
      @user_1 = User.create(uid: 1, access_token: "token", access_secret: "secret")
      @user_2 = User.create(uid: 2, access_token: "token", access_secret: "secret")
      @troll_10 = Troll.create(uid: 10)
      @troll_20 = Troll.create(uid: 20)

      Blockqueue.unblock_multiple_trolls_for_multiple_users(troll_list: [10,20], user_list: [1,2])

      expect(Blockqueue).to have_received(:unblock_troll).exactly(4).times
      expect(Blockqueue).to have_received(:unblock_troll).with(user: @user_1, troll: @troll_10).once
      expect(Blockqueue).to have_received(:unblock_troll).with(user: @user_1, troll: @troll_20).once
      expect(Blockqueue).to have_received(:unblock_troll).with(user: @user_2, troll: @troll_10).once
      expect(Blockqueue).to have_received(:unblock_troll).with(user: @user_2, troll: @troll_20).once
    end
  end
end
