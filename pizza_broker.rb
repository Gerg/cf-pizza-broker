require 'sinatra'
require 'json'
require 'logger'

$stdout.sync = true
$stderr.sync = true
 class PizzaBroker < Sinatra::Base
  def initialize
    @orders = {}
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
  end

  get "/v2/catalog" do
    content_type :json
    @logger.info("********* Sending catalog... ********")
    File.open("pizza_catalog.json")
  end

  put "/v2/service_instances/:id" do |id|
    content_type :json

    if params['accepts_incomplete']
      @orders[id] = 'baking'
      @logger.info("********* Order recieved: #{id} ********")
      status 202
    else
      status 422
    end

    {}.to_json
  end

  get "/v2/service_instances/:id/last_operation" do |id|
    content_type :json
    @logger.info("******** Poll recieved for: #{id} ***********")
    {description: @orders[id], state: 'succeeded'}.to_json
  end
end
