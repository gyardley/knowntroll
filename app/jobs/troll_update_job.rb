class TrollUpdateJob

  def perform
    Rails.logger.info "TrollUpdateJob has begun!"

    Troll.update_trolls
  end
end