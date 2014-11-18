class BlocksRefreshJob

  def perform
    Rails.logger.info "BlocksRefreshJob has begun!"

    User.all.each do |user|
      user.refresh_blocks
    end
  end
end
