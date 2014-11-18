require File.expand_path('../../config/boot',        __FILE__)
require File.expand_path('../../config/environment', __FILE__)
require 'clockwork'

include Clockwork

every(1.minute, 'TrollUpdateJob') {
  jobs = Delayed::Job.all.collect { |d| d.handler }
  Delayed::Job.enqueue TrollUpdateJob.new unless jobs.include?("--- !ruby/object:TrollUpdateJob {}")
}

every(3.minutes, 'BlockJob') {
  jobs = Delayed::Job.all.collect { |d| d.handler }
  Delayed::Job.enqueue BlockJob.new unless jobs.include?("--- !ruby/object:BlockJob {}")
}

every(15.minutes, 'BlockRefreshJob') {
  jobs = Delayed::Job.all.collect { |d| d.handler }
  Delayed::Job.enqueue BlocksRefreshJob.new unless jobs.include?("--- !ruby/object:BlocksRefreshJob {}")
}

every(15.minutes, 'FriendsRefreshJob') {
  jobs = Delayed::Job.all.collect { |d| d.handler }
  Delayed::Job.enqueue FriendsRefreshJob.new unless jobs.include?("--- !ruby/object:FriendsRefreshJob {}")
}