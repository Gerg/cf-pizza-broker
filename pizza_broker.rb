require 'sinatra'
require 'json'
require 'net/http'
require 'logger'
require 'rest-client'

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

      cart_url = "https://api.delivery.com/customer/cart/3022"
      params = {
        order_type: "delivery",
        item: {
          item_id: "E2328",
          item_qty: 1,
          option_qty: {
            E2329: 1,
            E2330: 1,
            E2331: 1,
            E2636: 1,
            E2637: 1
          }
        }
      }

      resp = RestClient::Request.execute(method: :post,
                                  url: cart_url,
                                  payload: params,
                                  headers: {
                                    :"Authorization" => "Bearer " + ENV["DELIVERY_BEARER"],
                                    :"Content-type" => "application/json"
                                  })

      status 202 if resp.code == 200
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
