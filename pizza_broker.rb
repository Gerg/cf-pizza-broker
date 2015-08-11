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

    if params['accepts_incomplete'] && ENV["DELIVERY_BEARER"]
      @orders[id] = 'Order placed'
      @logger.info("********* Order received: #{id} ********")

      response_code = add_pizza_to_cart
      if response_code == 200
        response_code = pay_for_pizza
        if response_code == 200
          @logger.info("********* Order paid ********")
          status 202
        else
          @logger.info("********* Payment failed ********")
          status 500
        end
      else
        @logger.info("********* Adding to cart failed ********")
        status 500
      end
    else
      status 422
    end

    {}.to_json
  end

  get "/v2/service_instances/:id/last_operation" do |id|
    content_type :json
    @logger.info("******** Poll received for: #{id} ***********")
    {description: @orders[id], state: 'succeeded'}.to_json
  end

  def add_pizza_to_cart
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
   @logger.info("********* Placing order ********")

   resp = RestClient::Request.execute(method: :post,
     url: cart_url,
     payload: params,
     headers: {
       :"Authorization" => "Bearer " + ENV["DELIVERY_BEARER"],
       :"Content-type" => "application/json"
     })

    resp.code
  end

  def pay_for_pizza
    checkout_url = "https://api.delivery.com/customer/cart/3022/checkout"
    params = {
      tip: 3.00,
      location_id: 2618175,
      payments: [
        {
          type: 'credit_card',
          id: 4199129
        }
      ],
      order_type: 'delivery',
      instructions: 'Call 774-270-4127 when you arrive at address'
    }

    response = RestClient::Request.execute(method: :post,
      url: checkout_url,
      payload: params,
      headers:{
        :"Authorization" => "Bearer " + ENV["DELIVERY_BEARER"],
        :"Content-type" => "application/json"
      }
    )

    response.code
 end
end
