require 'rails_helper'

RSpec.describe BlockJob do

  describe "#unique_tasks" do
    before(:each) do
      @user_a = User.create(uid: 1, access_token: "token", access_secret: "secret")
      @user_b = User.create(uid: 2, access_token: "token", access_secret: "secret")
      @user_c = User.create(uid: 3, access_token: "token", access_secret: "secret")
      @user_d = User.create(uid: 4, access_token: "token", access_secret: "secret")

      @troll_w = Troll.create(uid: 10, name: "W Troll")
      @troll_x = Troll.create(uid: 20, name: "X Troll")
      @troll_y = Troll.create(uid: 30, name: "Y Troll")
      @troll_z = Troll.create(uid: 40, name: "Z Troll")
    end

    it "should select one task per user only" do
      Blockqueue.create(user: @user_a, troll: @troll_w, task: "block")
      Blockqueue.create(user: @user_a, troll: @troll_x, task: "block")
      Blockqueue.create(user: @user_b, troll: @troll_y, task: "block")
      Blockqueue.create(user: @user_b, troll: @troll_z, task: "block")

      expect(BlockJob.new.unique_tasks).to satisfy { |tasks| tasks.count == 2 }
      expect(BlockJob.new.unique_tasks).to satisfy { |tasks| tasks.select { |task| task.user == @user_a }.size == 1 }
      expect(BlockJob.new.unique_tasks).to satisfy { |tasks| tasks.select { |task| task.user == @user_b }.size == 1 }
    end

    it "should select one task per troll only" do
      Blockqueue.create(user: @user_a, troll: @troll_w, task: "block")
      Blockqueue.create(user: @user_b, troll: @troll_w, task: "block")
      Blockqueue.create(user: @user_c, troll: @troll_x, task: "block")
      Blockqueue.create(user: @user_d, troll: @troll_x, task: "block")

      expect(BlockJob.new.unique_tasks).to satisfy { |tasks| tasks.count == 2 }
      expect(BlockJob.new.unique_tasks).to satisfy { |tasks| tasks.select { |task| task.troll == @troll_w }.size == 1 }
      expect(BlockJob.new.unique_tasks).to satisfy { |tasks| tasks.select { |task| task.troll == @troll_x }.size == 1 }
    end
  end

  describe "#process_task" do
    before(:each) do
      @user_a = User.create(uid: 1, access_token: "token", access_secret: "secret", block_list: [])
      @troll_w = Troll.create(uid: 10, name: "W Troll")
    end

    it "block task should remove identical block tasks from the queue" do
      job = BlockJob.new

      task = Blockqueue.create(user: @user_a, troll: @troll_w, task: "block")
      Blockqueue.create(user: @user_a, troll: @troll_w, task: "block")
      Blockqueue.create(user: @user_a, troll: @troll_w, task: "block")
      Blockqueue.create(user: @user_a, troll: @troll_w, task: "unblock")

      job.task = task

      expect { job.process_task }.to change { Blockqueue.count }.by(-3)
    end

    it "unblock task should remove identical unblock tasks from the queue" do
      job = BlockJob.new
      @user_a.block_list = [@troll_w.uid]
      @user_a.save
      @user_a.reload

      task = Blockqueue.create(user: @user_a, troll: @troll_w, task: "unblock")
      Blockqueue.create(user: @user_a, troll: @troll_w, task: "unblock")
      Blockqueue.create(user: @user_a, troll: @troll_w, task: "unblock")
      Blockqueue.create(user: @user_a, troll: @troll_w, task: "block")

      job.task = task

      expect { job.process_task }.to change { Blockqueue.count }.by(-3)
    end

    it "block task should add the troll to the user's block_list" do
      job = BlockJob.new

      task = Blockqueue.create(user: @user_a, troll: @troll_w, task: "block")
      job.task = task

      expect { job.process_task }.to change { @user_a.block_list }.to([@troll_w.uid])
    end

    it "unblock task should remove the troll from the user's block_list" do
      job = BlockJob.new
      @user_a.block_list = [@troll_w.uid]
      @user_a.save
      @user_a.reload

      Rails.logger.info "Block list: #{@user_a.block_list}"

      task = Blockqueue.create(user: @user_a, troll: @troll_w, task: "unblock")
      job.task = task

      expect { job.process_task }.to change { @user_a.block_list }.to([])
    end

    it "should clear the access_secret and access_token if unauthorized" do
      job = BlockJob.new

      user = User.create(uid: 1, access_token: "not_authorized", access_secret: "secret", block_list: [])
      task = Blockqueue.create(user: user, troll: @troll_w, task: "block")
      job.task = task

      expect { job.process_task }.to_not change { Blockqueue.count }
      expect(user.access_token).to eq('')
      expect(user.access_secret).to eq('')
    end
  end

  describe "#perform" do
    it "should call process_task once for each item returned by unique_task" do
      job = BlockJob.new

      allow(job).to receive(:unique_tasks).and_return([1, 2, 3])
      allow(job).to receive(:process_task)

      job.perform
      expect(job).to have_received(:process_task).thrice
    end
  end
end