class BlockJob

  attr_accessor :task

  def clear_queue
    Blockqueue.where(user: @task.user, troll: @task.troll, task: Blockqueue.tasks[@task.task]).each do |completed|
      completed.destroy
    end
  end

  def unique_users
    Blockqueue.all.map {|task| task.user }.uniq
  end

  def unique_tasks
    tasks = []
    rate_limited_trolls = []

    unique_users.each do |user|
      next_task = Blockqueue.where(user: user).where.not(troll_id: rate_limited_trolls).first
      if next_task
        tasks << next_task
        rate_limited_trolls << next_task.troll_id
      end
    end
    tasks
  end

  def process_task
    begin
      if @task.user.authorized?
        if @task.task == "block"
          Rails.logger.info "Blocking ID #{task.troll.uid} for #{@task.user.screen_name} (#{@task.user.uid})"
          response = @task.user.client.block(@task.troll.uid)
        elsif @task.task == "unblock"
          Rails.logger.info "Unblocking ID #{@task.troll.uid} for #{@task.user.screen_name} (#{@task.user.uid})"
          response = @task.user.client.unblock(@task.troll.uid)
        end

        Rails.logger.info "Response: #{response.inspect}"

        if response[0].class == Twitter::User
          Rails.logger.info "Blockqueue tasks before: #{Blockqueue.all.count}"
          Rails.logger.info "User blocks before: #{@task.user.block_list.count}"

          if @task.task == "block"
            @task.user.block_list << @task.troll.uid
            @task.user.block_list = @task.user.block_list.uniq || []
          elsif @task.task == "unblock"
            @task.user.block_list = @task.user.block_list - [@task.troll.uid]
          end

          @task.user.save

          clear_queue

          Rails.logger.info "Blockqueue tasks after: #{Blockqueue.all.count}"
          Rails.logger.info "User blocks after: #{@task.user.block_list.count}"
        end
      end
    rescue Twitter::Error::Unauthorized
      @task.user.access_token = ''
      @task.user.access_secret = ''
      @task.user.save
    end
  end

  def perform
    Rails.logger.info "BlockJob has begun!"

    unique_tasks.each do |task|
      @task = task

      process_task
    end
  end
end