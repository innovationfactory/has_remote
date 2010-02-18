module HasRemote

  class Synchronization < ActiveRecord::Base #:nodoc:
    set_table_name 'has_remote_synchronizations'

    named_scope :for, lambda { |model_name| {:conditions => ["model_name = ?", model_name.to_s.classify] } }

    validates_presence_of :model_name, :last_record_updated_at, :last_record_id
  end

end