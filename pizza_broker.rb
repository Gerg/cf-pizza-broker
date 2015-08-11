require 'sinatra'
require 'json'

class PizzaBroker < Sinatra::Base
  get "/v2/catalog" do
    content_type :json

    File.open("pizza_catalog.json")
  end
end
