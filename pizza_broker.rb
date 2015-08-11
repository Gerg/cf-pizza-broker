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
    @toppings_map = {"pepperoni"=> :E2472,
                     "sausage"=> :E2473,
                     "feta"=> :E2466,
                     "pesto"=> :E2456,
                     "olives"=> :E2491,
                     "peppers"=> :E2490 }
  end

  get "/v2/catalog" do
    content_type :json
    @logger.info("********* Sending catalog... ********")
    File.open("pizza_catalog.json")
  end

  put "/v2/service_instances/:id" do |id|
    content_type :json
    if params['accepts_incomplete'] && ENV["DELIVERY_BEARER"]
      request.body.rewind
      body = JSON.parse(request.body.read)
      toppings = body["parameters"]["toppings"]

      do_checkout = body["parameters"]["checkout"]

      selected_toppings = {}
      toppings.each do |topping|
        selected_toppings[@toppings_map[topping]] = 1
      end

      @logger.info("********* Order received: #{id} ********")

      response_code = add_pizza_to_cart_with_toppings(selected_toppings)
      if response_code == 200 && do_checkout
        response_code = pay_for_pizza
        if response_code == 200
          @logger.info("********* Order paid ********")
          @orders[id] = 'Order placed'
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

    response = check_recent_order_status

    if response.code == 200
      order = JSON.parse(response.body)['orders'].first
      if order['confirmed']
        {description: 'Order confirmed', state: 'succeeded'}.to_json
      else
        {description: @orders[id], state: 'in progress'}.to_json
      end
    else
      status 404
      {description: 'Order not found', state: 'failed'}.to_json
    end
  end

  delete "/v2/service_instances/:id" do
    content_type :json
    {}
  end

  def add_pizza_to_cart_with_toppings(selected_toppings)
   cart_url = "https://api.delivery.com/customer/cart/3022"
   params = {
     order_type: "delivery",
     item: {
       item_id: "E2328",
       item_qty: 1,
       option_qty: {
         E2329: 1,
         E2453: 1,
         E2454: 1,
         E2636: 1,
         E2637: 1
       }.merge(selected_toppings)
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

   @logger.info("Response: #{resp.inspect}")

    resp.code
  end

  def pay_for_pizza
    checkout_url = "https://api.delivery.com/customer/cart/3022/checkout"
    params = {
      tip: 3.00,
      location_id: 2618175,
      payments: {
        :'0' => {
          type: 'credit_card',
          id: '4199129'
        }
      },
      order_type: 'delivery',
      instructions: 'Call 774-270-4127 when you arrive at address'
    }

    begin
    response = RestClient::Request.execute(method: :post,
      url: checkout_url,
      payload: params,
      headers:{
        :"Authorization" => "Bearer " + ENV["DELIVERY_BEARER"],
        :"Content-type" => "application/json"
      }
    )

    @logger.info("Response: #{response.inspect}")

    rescue Exception => e
    @logger.info("Response: #{e.response.inspect}")
    end

    response.code
  end

  def check_recent_order_status
    order_status_url = "https://api.delivery.com/customer/orders/recent"
    response = RestClient::Request.execute(method: :get,
      url: order_status_url,
      payload: {},
      headers:{
        :"Authorization" => "Bearer " + ENV["DELIVERY_BEARER"],
        :"Content-type" => "application/json"
      }
    )

    return response
  end
end
