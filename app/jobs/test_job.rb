TestJob = Struct.new(:placeholder) do
  def perform
    Rails.logger.info "Test Job has successfully run!"
  end
end