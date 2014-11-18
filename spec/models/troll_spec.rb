require 'rails_helper'

RSpec.describe Troll, :type => :model do
  describe ".initialize_troll" do
    it "should create a basic troll if troll doesn't exist" do
      expect{Troll.initialize_troll(twitter_id: 123)}.to change{Troll.count}.by(1)
      expect(Troll.last.uid).to eq(123)
      expect(Troll.last.screen_name).to eq("ID 123")
    end

    it "should return existing troll if troll already exists" do
      troll = Troll.create(uid: 123, screen_name: "exists")
      expect(Troll.initialize_troll(twitter_id: 123)).to eq(troll)
    end
  end

  describe ".create_troll" do

    # data here comes from the support/user_generator.rb file

    before(:each) do
      @twitter_user = Troll.client.users([1337]).first
    end

    it "should create a troll if the troll doesn't exist" do
      expect{Troll.create_troll(twitter_user: @twitter_user)}.to change{Troll.count}.by(1)
      troll = Troll.last
      expect(troll.uid).to eq(1337)
      expect(troll.screen_name).to eq("troll_1337")
      expect(troll.name).to eq("Troll_1337")
      expect(troll.image_url).to eq("https://www.example.com/profile.png")
      expect(troll.checked).to be true
    end

    it "should return existing troll if troll already exists" do
      troll = Troll.create(uid: 1337, screen_name: "exists")
      expect(Troll.create_troll(twitter_user: @twitter_user)).to eq(troll)
    end
  end

  describe ".update_trolls" do

    it "syncs trolls for unchecked trolls if present" do
      # having issues mocking sync_troll for reasons I don't understand, so I'm just checking
      # for the results of the sync troll code

      troll_a = Troll.create(uid: 1, checked: false)

      Troll.update_trolls

      troll_a.reload

      expect(troll_a.checked).to be true
      expect(troll_a.name).to eq("Troll_1")
      expect(troll_a.screen_name).to eq("troll_1")
    end

    it "syncs trolls for up to but not more than 100 unchecked trolls" do
      (1..105).to_a.each do |index|
        Troll.create(uid: index, checked: false)
      end

      expect(Troll.where(checked: true).count).to eq(0)

      Troll.update_trolls

      expect(Troll.where(checked: true).count).to eq(100)
    end

    it "syncs trolls for old trolls if no unchecked trolls present" do
      troll_a = Troll.create(uid: 10, checked: true, last_checked: Time.now)

      travel 2.days do
        expect {
          Troll.update_trolls
          troll_a.reload
        }.to change { troll_a.last_checked }
      end
    end

    it "does not sync trolls if no unchecked or old trolls present" do
      troll_a = Troll.create(uid: 1, checked: true, last_checked: Time.now)

      travel 1.hour do
        expect {
          Troll.update_trolls
          troll_a.reload
        }.to_not change { troll_a.last_checked }
      end
    end

    it "syncs troll for up to but not more than 100 old trolls if no unchecked trolls present" do
      (1..105).to_a.each do |index|
        Troll.create(uid: index, checked: true, last_checked: Time.now)
      end

      travel 2.days do
        Troll.update_trolls
        expect(Troll.where(last_checked: (Time.now - 1.minute)..(Time.now)).count).to eq(100)
      end
    end

    it "calls process rejected trolls for trolls not returned" do
      troll_a = Troll.create(uid: 100000, checked: false)
      troll_b = Troll.create(uid: 1337, checked: false)
      allow(Troll).to receive(:process_rejected_trolls)

      Troll.update_trolls
      expect(Troll).to have_received(:process_rejected_trolls).with([100000]).once
    end

    it "calls process rejected trolls for all trolls if Twitter::NotFound error" do
      troll_a = Troll.create(uid: 1234, checked: false)
      troll_b = Troll.create(uid: 5678, checked: false)
      troll_c = Troll.create(uid: 9012, checked: false)
      allow(Troll).to receive(:process_rejected_trolls)

      Troll.update_trolls
      expect(Troll).to have_received(:process_rejected_trolls).with([1234,5678,9012]).once
    end
  end

  describe "#sync_troll" do

    before(:each) do
      @user = Troll.client.users([5000]).first
    end

    it "updates last checked to now" do
      troll = Troll.create(uid: 5000, checked: false)

      expect { troll.sync_troll(twitter_user: @user) }.to change { troll.last_checked }
      expect(troll.last_checked).to satisfy { |time| time > Time.now - 1.minute }
    end

    it "sets checked to true" do
      troll = Troll.create(uid: 5000, checked: false)

      expect { troll.sync_troll(twitter_user: @user) }.to change { troll.checked }.to(true)
    end

    it "updates the image_url, screen_name, and name" do
      troll = Troll.create(uid: 5000, checked: false)

      troll.sync_troll(twitter_user: @user)
      troll.reload

      expect(troll.screen_name).to eq("troll_5000")
      expect(troll.name).to eq("Troll_5000")
      expect(troll.image_url).to eq("https://www.example.com/profile.png")
    end
  end

  describe ".process_rejected_trolls" do
    it "sets notfound to true if Twitter::Error::NotFound returned" do
      troll_a = Troll.create(uid: 1234, checked: false)

      Troll.process_rejected_trolls([1234])

      troll_a.reload
      expect(troll_a.notfound).to be true
    end

    it "sets suspended to true if Twitter::Error::Forbidden returned" do
      troll_a = Troll.create(uid: 5678, checked: false)

      Troll.process_rejected_trolls([5678])

      troll_a.reload
      expect(troll_a.suspended).to be true
    end
  end
end
