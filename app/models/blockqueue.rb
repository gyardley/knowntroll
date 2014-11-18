class Blockqueue < ActiveRecord::Base

  default_scope { order('created_at ASC') }

  belongs_to :user
  belongs_to :troll

  enum task: [:block, :unblock]

  # args - list: an Array of twitter uids, and user: a User instance
  def self.block_multiple_trolls_for_single_user(args)
    list = args.fetch(:list)
    user = args.fetch(:user)

    list.each do |uid|
      self.block_troll(troll: Troll.where(uid: uid).first, user: user)
    end
  end

  # args - list: an Array of twitter uids, and user: a User instance
  def self.unblock_multiple_trolls_for_single_user(args)
    list = args.fetch(:list)
    user = args.fetch(:user)

    list.each do |uid|
      self.unblock_troll(troll: Troll.where(uid: uid).first, user: user)
    end
  end

  # args - list: an Array of twitter uids, and troll: a Troll instance
  def self.block_single_troll_for_multiple_users(args)
    list = args.fetch(:list)
    troll = args.fetch(:troll)

    list.each do |uid|
      self.block_troll(troll: troll, user: User.where(uid: uid).first)
    end
  end

  # args - list: an Array of twitter uids, and troll: a Troll instance
  def self.unblock_single_troll_for_multiple_users(args)
    list = args.fetch(:list)
    troll = args.fetch(:troll)

    list.each do |uid|
      self.unblock_troll(troll: troll, user: User.where(uid: uid).first)
    end
  end

  # args - user_list: an Array of twitter uids, and troll_list: an Array of twitter uids
  def self.block_multiple_trolls_for_multiple_users(args)
    user_list = args.fetch(:user_list)
    troll_list = args.fetch(:troll_list)

    troll_list.each do |troll|
      user_list.each do |user|
        self.block_troll(troll: Troll.where(uid: troll).first, user: User.where(uid: user).first)
      end
    end
  end

  # args - user_list: an Array of twitter uids, and troll_list: an Array of twitter uids
  def self.unblock_multiple_trolls_for_multiple_users(args)
    user_list = args.fetch(:user_list)
    troll_list = args.fetch(:troll_list)

    troll_list.each do |troll|
      user_list.each do |user|
        self.unblock_troll(troll: Troll.where(uid: troll).first, user: User.where(uid: user).first)
      end
    end
  end

  # method for blocking a single individual
  # args: troll, a Troll instance, and user, a User instance
  def self.block_troll(args)
    troll = args.fetch(:troll)
    user = args.fetch(:user)

    return if user.friend_list.include?(troll.uid)

    # remove any unblock action from the queue
    Blockqueue.remove_unblock_in_queue(args) # come back to later

    unless user.block_list.include?(troll.uid)
      # the user needs to be blocked, write to the block queue
      Blockqueue.create(task: :block, troll: troll, user: user)
    end
  end

  # method for unblocking a single individual
  # args: troll, a Troll instance, and user, a User instance
  def self.unblock_troll(args)
    troll = args.fetch(:troll)
    user = args.fetch(:user)

    # can't unblock if they were never blocked in the first place, so check
    if user.block_list.include?(troll.uid)

      # if any blocks are still pending, remove them from the queue
      Blockqueue.remove_block_in_queue(args)

      # if there's still a list blocking the troll, they'll stay blocked
      unless user.has_list_with_block?(troll: troll)
        Blockqueue.create(task: :unblock, troll: troll, user: user)
      end
    end
  end

  private

  # method wipes out any unblock actions for that user in the blockqueue
  # used when we've just added a block, so it won't get undone and then redone
  # args: user, a User instance, and troll, a Troll instance
  def self.remove_unblock_in_queue(args)
    troll = args.fetch(:troll)
    user = args.fetch(:user)
    if Blockqueue.exists?(user: user, troll: troll, task: Blockqueue.tasks[:unblock])
      Blockqueue.where(user: user, troll: troll, task: Blockqueue.tasks[:unblock]).each do |job|
        job.destroy
      end
    end
  end

  # method wipes out any block actions for that user in the blockqueue
  # used when we've just added an unblock, so it won't get undone and then redone
  # args: user, a User instance, and troll, a Troll instance
  def self.remove_block_in_queue(args)
    troll = args.fetch(:troll)
    user = args.fetch(:user)
    if Blockqueue.exists?(user: user, troll: troll, task: Blockqueue.tasks[:block])
      Blockqueue.where(user: user, troll: troll, task: Blockqueue.tasks[:block]).each do |job|
        job.destroy
      end
    end
  end


end
