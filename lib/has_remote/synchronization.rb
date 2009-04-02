module HasRemote
  
  class Synchronization < ActiveRecord::Base #:nodoc:
    set_table_name 'has_remote_synchronizations'
    validates_presence_of :model_name, :latest_change
  end
  
end