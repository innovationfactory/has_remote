module HasRemote
  
  # Contains class methods regarding synchronization of changed, added and deleted remotes.
  #
  # === Synchronization examples
  #
  # Update all cached attributes, destroy deleted records and add new records for all models that have a remote:
  #  HasRemote.synchronize!
  #
  # For users only:
  #  User.synchronize!
  #
  # You can also update a single record's cached attributes:
  #  @user.update_cached_attributes
  #
  # Or with also saving the record:
  #  @user.update_cached_attributes!
  #
  # You can make your application call these methods whenever you need to be sure
  # your cache is up to date or use the 'hr:sync' rake task to synchronize all models
  # from the command line.
  #
  # *Note* 
  # All remote resources need to have an 'updated_at' field in order for synchronization to work. Records will 
  # be destroyed if their remote resource's 'deleted_at' time lies before the time of synchronization.
  #
  module Synchronizable

    # Returns an array of all attributes that are locally cached.
    #
    def cached_attributes
      @cached_attributes ||= []
    end
    
    # Returns all remote objects that have been changed since the given time or one week ago if no
    # time is given. This may include new and optionally deleted (tagged by a 'deleted_at' attribute) resources.
    #
    # This is used by the <tt>synchronize!</tt> class method. By default
    # it queries '/updated?since=<time>' on your resources URL, where 'time' is
    # the latest updated_at time of the last processed remote objects.
    #
    # You may need to override this method in your model to match your host's REST API or to change
    # the default time, e.g.:
    #
    #  def self.changed_remotes_since(time = nil)
    #    time ||= 12.hours.ago
    #    User::Remote.find :all, :from => :search, :params => {:updated_since => time.strftime('...') }
    #  end
    #
    def changed_remotes_since(time = nil)
      time ||= 1.week.ago 
      remote_class.find :all, :from => :updated, :params => {:since => time.to_s}  
    end
    
    # Will update all records that have been created, updated or deleted on the remote host
    # since the last successful synchronization.
    #
    def synchronize!
      logger.info( "*** Start synchronizing #{table_name} at #{Time.now.to_s :long} ***\n" )
      @update_count = 0
      begin
        changed_objects = changed_remotes_since( synchronized_at )
        if changed_objects.any?
          # Do everything within transaction to prevent ending up in half-synchronized situation if an exception is raised.
          transaction { sync_all_records_for(changed_objects) }
        else
          logger.info( " - No #{table_name} to update.\n" )
        end
      rescue => e
        logger.warn( " - Synchronization of #{table_name} failed: #{e} \n #{e.backtrace}" )
      else
        self.synchronized_at = changed_objects.map(&:updated_at).sort.last if changed_objects.any?  
        logger.info( " - Updated #{@update_count} #{table_name}.\n" ) if @update_count > 0
      ensure
        logger.info( "*** Stopped synchronizing #{table_name} at #{Time.now.to_s :long} ***\n" )
      end
    end
    
    # Time of the last successful synchronization.
    #
    def synchronized_at
      HasRemote::Synchronization.for(self.name).latest_change
    end
    
  private

    def synchronized_at=(time) #:nodoc:
      HasRemote::Synchronization.create!(:model_name => self.name, :latest_change => time)
    end

    def sync_all_records_for(resources) #:nodoc:
      resources.each { |resource| sync_all_records_for_resource(resource) }
    end
    
    def sync_all_records_for_resource(resource) #:nodoc:
      records = find(:all, :conditions => ["#{remote_foreign_key} = ?", resource.send(remote_primary_key)])
      if records.empty?
        create_record_for_resource(resource)
      else
        records.each { |record| sync_record_for_resource(record, resource) }
      end
    end
    
    def sync_record_for_resource(record, resource) #:nodoc:
      if resource.respond_to?(:deleted_at) && resource.deleted_at && resource.deleted_at <= Time.now
        delete_record_for_resource(record, resource)
      else
        update_and_save_record_for_resource(record, resource)
      end
    end
    
    def update_and_save_record_for_resource(record, resource) #:nodoc:
      was_it_new = record.new_record?
      cached_attributes.each do |remote_attr|
        local_attr = remote_attribute_aliases[remote_attr] || remote_attr
        record.send :write_attribute, local_attr, resource.send(remote_attr)
      end
      record.skip_update_cache = true # Dont update cache again on save:
      if record.save!
        @update_count += 1
        logger.info( was_it_new ? " - Created #{name.downcase} with id #{record.id}.\n" : " - Updated #{name.downcase} with id #{record.id}.\n" )
      end
    end
    
    def delete_record_for_resource(record, resource) #:nodoc:
      record.destroy
      logger.info( " - Deleted #{name.downcase} with id #{record.id}.\n" )
    end
    
    def create_record_for_resource(resource) #:nodoc:
      update_and_save_record_for_resource(new(remote_foreign_key => resource.send(remote_primary_key)), resource)
    end

  end  
end