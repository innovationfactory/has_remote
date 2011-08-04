module HasRemote

  # This model represents a synchronization performed by HasRemote.
  #
  # ==== Attributes:
  #
  # [model_name] (String) Name of the model that was synchronized.
  # [last_record_updated_at] (Time) Timestamp representing the <tt>updated_at</tt> of the last record that was synchronized during this synchronization.
  # [last_record_id] (Integer) ID of the last record that was synchronized during this synchronization.
  # [created_at] (Time) time when this synchronization finished.
  #
  class Synchronization < ActiveRecord::Base #:nodoc:
    set_table_name 'has_remote_synchronizations'

    scope :for, lambda { |model_name| where(:model_name => model_name.to_s.classify) }

    validates_presence_of :model_name, :last_record_updated_at, :last_record_id
  end

end