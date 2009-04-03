module HasRemoteSpec
  class User < ActiveRecord::Base
    has_remote :site => "http://dummy.local" do |remote|
      remote.attribute :name
      remote.attribute :email, :local_cache => true
    end
  end
end