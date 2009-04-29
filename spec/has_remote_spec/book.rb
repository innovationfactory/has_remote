module HasRemoteSpec
  class RemoteBook < ActiveResource::Base; end
  
  class Book < ActiveRecord::Base   
    has_remote :through => "HasRemoteSpec::RemoteBook", :foreign_key => :custom_remote_id
  end
end