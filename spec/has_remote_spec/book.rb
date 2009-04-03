module HasRemoteSpec
  class RemoteBook < ActiveResource::Base; end
  
  class Book < ActiveRecord::Base
    include HasRemote
    attr_accessor :remote_id
    
    has_remote :through => "HasRemoteSpec::RemoteBook"

  end
end