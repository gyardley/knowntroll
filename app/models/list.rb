class List < ActiveRecord::Base

  serialize :block_list, Array

  has_and_belongs_to_many :users

  validates :name, presence: { message: "You must give your list a name." }

  def owner
    User.find(owner_id)
  end

  def trolls
    block_list.map { |troll_id| Troll.where(uid: troll_id).first }
  end

  def user_list
    self.users.map { |user| user.uid }
  end

  def self.of_friends(user)
    # for each mutual friend, for each of that friend's lists,
    # return each list that the user doesn't belong to

    user.mutual_friends.flat_map { |friend|
      friend.lists.select { |list|
        !user.lists.exists?(id: list.id)
      }
    }.uniq
  end

end
