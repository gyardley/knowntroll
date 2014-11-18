require 'rails_helper'

RSpec.describe List, :type => :model do

  describe ".of_friends" do
    it "returns the lists of mutual friends" do
      @user_a = User.create(uid: 1, access_token: "token", access_secret: "secret", friend_list: [2, 3, 4])
      @user_b = User.create(uid: 2, access_token: "token", access_secret: "secret", friend_list: [1])
      @user_c = User.create(uid: 3, access_token: "token", access_secret: "secret", friend_list: [1])

      @list_a = @user_a.lists.create(name: "A", owner_id: @user_a.id, block_list: [])
      @list_b_1 = @user_b.lists.create(name: "B_1", owner_id: @user_b.id, block_list: [])
      @list_b_2 = @user_b.lists.create(name: "B_2", owner_id: @user_b.id, block_list: [])
      @list_c = @user_c.lists.create(name: "C", owner_id: @user_b.id, block_list: [])

      allow(@user_a).to receive(:mutual_friends).and_return([@user_b, @user_c])

      expect(List.of_friends(@user_a)).to eq([@list_b_1, @list_b_2, @list_c])
    end
  end

  describe "#owner" do
    it "returns the list's owner" do
      @user = User.create(uid: 1, access_token: "token", access_secret: "secret")
      @list = @user.lists.create(name: "A", owner_id: @user.id, block_list: [])

      expect(@list.owner).to eq(@user)
    end
  end

  describe "#trolls" do
    it "returns an array of the list's trolls" do
      @a = Troll.create(uid: 10)
      @b = Troll.create(uid: 20)
      @list = List.create(name: "A", owner_id: 1337, block_list: [10, 20])

      expect(@list.trolls).to eq([@a, @b])
    end
  end
end
