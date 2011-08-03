class User < ActiveRecord::Base
  has_remote :site => "http://dummy.local" do |remote|
    remote.attribute :name
    remote.attribute :email, :local_cache => true
    remote.attribute :phone, :as => :telephone
  end

  before_save :update_cached_attributes
end