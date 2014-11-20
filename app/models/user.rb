class User < ActiveRecord::Base

  default_scope { where(oversized: false) }

  serialize :friend_list, Array
  serialize :block_list, Array
  serialize :own_blocks, Array

  has_and_belongs_to_many :lists
  has_many :blockqueues

  attr_accessor :twitter_client

  def self.from_omniauth(auth)

    # create user if it hasn't been created
    user = where(uid: auth.uid).first_or_create do |user|
      user.uid = auth.uid
      user.access_token = auth.credentials.token
      user.access_secret = auth.credentials.secret
      user.image_url = auth.info.image.to_s
      user.access_token = auth.credentials.token
      user.access_secret = auth.credentials.secret
      user.name = auth.info.name
      user.screen_name = auth.info.nickname
      user.save
      user.initialize_friends
      user.initialize_blocks
      user
    end

    user.image_url = auth.info.image.to_s
    user.access_token = auth.credentials.token
    user.access_secret = auth.credentials.secret
    user.name = auth.info.name
    user.screen_name = auth.info.nickname
    user.save

    user
  end

  def authorized?
    (self.access_token.blank? || self.access_secret.blank?) ? false : true
  end

  def created_lists
    lists.where(owner_id: id)
  end

  def subscribed_lists
    lists.where.not(owner_id: id)
  end

  def no_email?
    self.email.blank? && (self.declined == false)
  end

  def own_trolls
    own_blocks.map { |troll_id| Troll.where(uid: troll_id).first }
  end

  # sets up the initial blocks on account creation
  def initialize_blocks
    begin
      self.block_list = self.own_blocks = client.blocked_ids.to_a
      self.save

      # get the first hundred and do them properly
      unless self.block_list.blank?
        first_batch = client.users(self.block_list.slice(0,100))
        first_batch.each do |block|
          Troll.create_troll(twitter_user: block)
        end

        # do the rest half-assed and fetch later with the refresh blocks task
        unless self.block_list.count < 101
          rest_of_trolls = self.block_list - self.block_list.slice(0,100)
          rest_of_trolls.each do |block_id|
            Troll.initialize_troll(twitter_id: block_id)
          end
        end
      end
    rescue Twitter::Error::TooManyRequests
      self.oversized = true
      self.save
    end
  end

  def initialize_friends
    begin
      self.friend_list = client.friend_ids.to_a
      self.save
    rescue Twitter::Error::TooManyRequests
      self.oversized = true
      self.save
    end
  end

  def mutual_friend?(other_user)
    self.friend_list.include?(other_user.uid) && other_user.friend_list.include?(self.uid)
  end

  def mutual_friends
    # get the friends who are KnownTroll users via map and grep and then find mutual friends with select
    friend_list.map { |friend| User.where(uid: friend).first }.grep(User).select { |user| self.mutual_friend?(user) }
  end

  # args - troll, a Troll instance
  def has_list_with_block?(args)
    troll_id = args.fetch(:troll).uid

    found = lists.any? { |list| list.block_list.include?(troll_id) }
    found = true if self.own_blocks.include?(troll_id)

    found
  end

  def client
    twitter_client ||= Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['twitter_key']
      config.consumer_secret     = ENV['twitter_secret']
      config.access_token        = access_token
      config.access_token_secret = access_secret
    end
  end

  def refresh_friends
    begin
      if self.authorized?
        new_friends = client.friend_ids.to_a
        old_friends = friend_list

        removed_friends = old_friends - new_friends

        # delete old friends
        removed_friends.each do |friend|

          # if the removed friend is a troll and the troll's on any block_list, add the block back
          if Troll.exists?(uid: friend.to_s) && lists.any? { |list| list.block_list.include?(friend) }
            troll = Troll.where(uid: friend.to_s).first
            Blockqueue.block_troll(troll: troll, user: self)
          end

          if User.exists?(uid: friend.to_s)
            full_friend = User.where(uid: friend.to_s).first
            wipe_removed_friends_lists(friend: full_friend)
            full_friend.wipe_removed_friends_lists(friend: self)
          end
        end

        self.friend_list = new_friends
        self.save
      end
    rescue Twitter::Error::Unauthorized
      self.access_token = ''
      self.access_secret = ''
      self.save
    rescue Twitter::Error::TooManyRequests
      self.oversized = true
      self.save
    end
  end

  def refresh_blocks
    begin
      if self.authorized?

        new_blocks = client.blocked_ids.to_a
        old_blocks = block_list

        added_blocks = new_blocks - old_blocks
        removed_blocks = old_blocks - new_blocks

        # add all the block_lists together to get the subscribed_blocks
        subscribed_blocks = lists.map { |list| list.block_list }.inject([], :+)
        # select only the added blocks that aren't in the subscribed_blocks
        new_own_blocks = added_blocks.select { |block| !subscribed_blocks.include?(block) }

        self.block_list = new_blocks
        self.save

        unless new_own_blocks.empty?

          # first, check for blocks that have been added
          new_own_blocks.each do |block|
            # unless subscribed_blocks.include?(block)
            Troll.initialize_troll(twitter_id: block)
          end
        end

        unless new_own_blocks.empty? && removed_blocks.empty?

          self.own_blocks = self.own_blocks + new_own_blocks - removed_blocks
          self.save

          self.created_lists.each do |list|
            current_list_block_list = list.block_list
            if list.auto_add_new_blocks == true
              list.block_list = current_list_block_list + new_own_blocks - removed_blocks
            else
              list.block_list = current_list_block_list - removed_blocks
            end

            actually_added_blocks   = list.block_list - current_list_block_list
            actually_removed_blocks = current_list_block_list - list.block_list

            list.save

            if list.users.count > 1
              subscribe_list = list.user_list - [self.uid]
              unless actually_added_blocks.empty?
                Blockqueue.block_multiple_trolls_for_multiple_users(user_list: subscribe_list, troll_list: actually_added_blocks)
              end
              unless actually_removed_blocks.empty?
                Blockqueue.unblock_multiple_trolls_for_multiple_users(user_list: subscribe_list, troll_list: actually_removed_blocks)
              end
            end
          end
        end
      end
    rescue Twitter::Error::Unauthorized
      self.access_token = ''
      self.access_secret = ''
      self.save
    rescue Twitter::Error::TooManyRequests
      self.oversized = true
      self.save
    end
  end

  # args - friend, a User instance
  def wipe_removed_friends_lists(args)
    former_friend = args.fetch(:friend)
    # only work on lists where the former friend is the owner
    lists.select { |list| list.owner_id == former_friend.id }.each do |list|
      Blockqueue.unblock_multiple_trolls_for_single_user(list: list.block_list, user: self)
      lists.delete(list)
    end
  end
end
