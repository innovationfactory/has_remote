module HasRemoteSpec
  class Product < ActiveRecord::Base
    has_remote :site => "http://dummy.local" do |remote|
      remote.finder do |id|
        Product::Remote.find :one, :from => "/special/place/products/#{id}.xml"
      end
    end
  end
end