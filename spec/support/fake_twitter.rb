require 'sinatra/base'

class FakeTwitter < Sinatra::Base
  set :views, Proc.new { File.join(root, "fixtures") }

  before do
    # puts request.inspect
    if request.env["HTTP_AUTHORIZATION"] =~ /not_authorized/
      status 401
      File.open(File.dirname(__FILE__) + '/fixtures/error_unauthorized.json', 'rb').read
    elsif request.env["HTTP_AUTHORIZATION"] =~ /too_many_requests/
      status 429
      File.open(File.dirname(__FILE__) + '/fixtures/too_many_requests.json', 'rb').read
    end
  end

  post '/oauth2/token' do
    erb :oauth_token
  end

  get '/1.1/account/verify_credentials.json' do
    erb :verify_credentials
  end

  get '/1.1/friends/ids.json' do
    erb :friends_ids
  end

  post '/1.1/blocks/destroy.json' do
    erb :blocks_destroy
  end

  post '/1.1/blocks/create.json' do
    erb :blocks_create
  end

  get '/1.1/blocks/ids.json' do

    if request.env["HTTP_AUTHORIZATION"] =~ /long_block_list/
      @list = (1001..1125).to_a.to_s
    else
      @list = (1001..1003).to_a.to_s
    end
    erb :blocks_ids
  end

  get '/1.1/users/show.json' do
    # for user where Twitter::NotFound error
    if params[:user_id] == "1234"
      status 404
      File.open(File.dirname(__FILE__) + '/fixtures/not_found.json', 'rb').read
    # for user where Twitter::Unauthorized error
    elsif params[:user_id] == "5678"
      status 403
      File.open(File.dirname(__FILE__) + '/fixtures/forbidden.json', 'rb').read
    else
      UserGenerator.new.as_json(params[:user_id]).to_json
    end
  end

  post '/1.1/users/lookup.json' do

    # this special case is for testing the Twitter::NotFound error
    if params[:user_id] == "1234,5678,9012"
      status 404
      File.open(File.dirname(__FILE__) + '/fixtures/not_found.json', 'rb').read
    else
      @array = params[:user_id].split(",")

      # we don't return data for 100000, 200000, etc. - for testing when data isn't returned
      @array.select{ |i| i.to_i % 100000 != 0 }.map do |r|
        UserGenerator.new.as_json(r)
      end.to_json
    end
  end
end