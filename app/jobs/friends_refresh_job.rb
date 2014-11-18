class FriendsRefreshJob

  def perform
    Rails.logger.info "FriendsRefreshJob has begun!"

    User.all.each do |user|
      user.refresh_friends
    end
  end
end