module HasRemote
  
  class Synchronization < ActiveRecord::Base #:nodoc:
    set_table_name 'has_remote_synchronizations'
    
    named_scope :for, lambda { |model_name| {:conditions => ["model_name = ?", model_name.to_s.classify] } } do
      def latest_change
        self.find(:first, :order => 'latest_change DESC').latest_change rescue nil
      end
    end
    
    validates_presence_of :model_name, :latest_change
  end
  
end