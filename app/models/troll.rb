class Troll < ActiveRecord::Base

  default_scope { order('created_at ASC') }

  has_many :blockqueues

  # args - twitter_id, an Integer
  def self.initialize_troll(args)
    twitter_id = args.fetch(:twitter_id)
    troll = Troll.where(uid: twitter_id).first_or_create do |troll|
      troll.uid = twitter_id
      troll.screen_name = "ID #{twitter_id}"
    end
  end

  # args - twitter_user, a Twitter::User object
  def self.create_troll(args)
    twitter_user = args.fetch(:twitter_user)
    Troll.where(uid: twitter_user.id).first_or_create do |troll|
      # avoids the Twitter::NullObject being unable to be cast to String for the comparison
      new_image_url = twitter_user.profile_image_uri_https.nil? ? "https://pbs.twimg.com/profile_images/523989065352232961/ZF2MvbfP_bigger.png" : twitter_user.profile_image_uri_https.to_s
      new_screen_name = twitter_user.screen_name.nil? ? "unknown" : twitter_user.screen_name
      new_name = twitter_user.name.nil? ? "" : twitter_user.name

      troll.uid = twitter_user.id
      troll.image_url = new_image_url
      troll.screen_name = new_screen_name
      troll.name = new_name
      troll.checked = true
      troll.last_checked = Time.now
    end
  end

  def self.update_trolls
    candidate_list = Troll.where(checked: false, suspended: false, notfound: false).limit(100)

    if candidate_list.blank?
      candidate_list = Troll.where(checked: true, suspended: false, notfound: false, last_checked: (Time.now - 10.years)..(Time.now - 1.day)).order(last_checked: :asc).limit(100)
    end

    unless candidate_list.blank?
      candidate_array = candidate_list.collect { |item| item.uid }
      begin
        data_array = Troll.client.users(candidate_array)
        # take care of the trolls that don't exist anymore
        rejected_trolls = candidate_array - data_array.map { |d| d.id }
        Troll.process_rejected_trolls(rejected_trolls)

        data_array.each do |twitter_user|
          troll = Troll.where(uid: twitter_user.id).first
          troll.sync_troll(twitter_user: twitter_user)
        end
      rescue Twitter::Error::NotFound
        # none of the candidates exist any more, take care of all of them
        Troll.process_rejected_trolls(candidate_array)
      end
    end

  end

  # args - twitter_user, a Twitter::User object
  def sync_troll(args)
    twitter_user = args.fetch(:twitter_user)
    self.last_checked = Time.now
    self.checked = true

    # avoids the Twitter::NullObject being unable to be cast to String for the comparison
    new_image_url = twitter_user.profile_image_uri_https.nil? ? "https://pbs.twimg.com/profile_images/523989065352232961/ZF2MvbfP_bigger.png" : twitter_user.profile_image_uri_https.to_s
    new_screen_name = twitter_user.screen_name.nil? ? "unknown" : twitter_user.screen_name
    new_name = twitter_user.name.nil? ? "none" : twitter_user.name

    unless ((self.image_url == new_image_url) && (self.screen_name == new_screen_name) && (self.name == new_name))
      self.image_url = new_image_url
      self.screen_name = new_screen_name
      self.name = new_name
    end
    self.save
  end

  private

  def self.client
    Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV['twitter_key']
      config.consumer_secret     = ENV['twitter_secret']
    end
  end

  def self.process_rejected_trolls(rejected_trolls)
    rejected_trolls.each do |troll|
      begin
        self.client.user(troll)
      rescue Twitter::Error::NotFound => e
        if e.code.to_s == "34"
          troll = Troll.where(uid: troll).first
          troll.notfound = true
          troll.save
        end
      rescue Twitter::Error::Forbidden => e
        if e.code.to_s == "63"
          troll = Troll.where(uid: troll).first
          troll.suspended = true
          troll.save
        end
      end
    end
  end
end
