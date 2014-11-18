class StaticController < ApplicationController

  before_filter :must_be_logged_out, only: [ :index ]

  def index
  end

end
