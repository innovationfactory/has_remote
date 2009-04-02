module HasRemoteSpec
  class User
    include HasRemote
    attr_accessor :remote_id
    
    has_remote :site => "http://dummy.local" do |remote|
      remote.attribute :name
    end

  end
end