module HasRemoteSpec
  class Cheese < ActiveRecord::Base
    validates_presence_of :maturity, :smell
    has_remote :site => "http://dummy.local"
    
    def before_validation_on_create
      self.smell = self.maturity * 10 if self.smell.nil?
    end
  end
end