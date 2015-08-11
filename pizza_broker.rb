require 'sinatra'
require 'json'

class PizzaBroker < Sinatra::Base
  get "/v2/catalog" do
    content_type :json

    File.open("pizza_catalog.json")
  end

  put "/v2/service_instances/:id" do
    content_type :json

    status 201
    {}.to_json
  end
end
