module HasRemote

  # Contains class methods regarding synchronization of changed, added and deleted remote data.
  #
  # ==== Synchronization examples:
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
  # your cache is up to date.
  #
  # You can also use a rake task to synchronize from the command line:
  #  rake hr:sync
  #
  # See the {file:README.rdoc README} for more rake options.
  #
  # @note All remote resources need to have an <tt>updated_at</tt> field in order for synchronization to work. Optionally, records will
  #       be destroyed if their remote has a <tt>deleted_at</tt> field and its time lies before the time of synchronization.
  #
  module Synchronizable

    # Returns an array of all attributes that are locally cached.
    #
    def cached_attributes
      @cached_attributes ||= []
    end

    # Returns all remote objects that have been changed since the last synchornization _(or since ever if no
    # time is given)_. This may include new and optionally deleted (tagged by a <tt>deleted_at</tt> attribute) resources.
    #
    # This method is called from the {#synchronize!} class method. By default
    # it queries <tt>/updated?since=[time]&last_record_id=[id]</tt> on your resources URL, where <tt>time</tt> is
    # the updated_at value of the last processed remote object and <tt>last_record_id</tt> is its ID.
    #
    # *Important:* If you are using synchronization you'll probably need to override this method in your model to match
    # your host's REST API; here's an example of another implementation:
    #
    #  def self.updated_remotes(options = nil)
    #    time = last_synchronization.try(:last_record_updated_at) || 12.hours.ago
    #    User::Remote.find :all, :from => :search, :params => { :updated_since => time.to_s(:db) }
    #  end
    #
    # @param [Hash] parameters The parameter options passed in to {#synchronize!} will be passed through to this method.
    #               They are used as request parameters for remotely requesting the updated records.
    #
    def updated_remotes( parameters = {} )
      time = last_synchronization.try(:last_record_updated_at) || DateTime.parse("Jan 1 1970")
      remote_class.find :all, :from => :updated, :params => { :since => time.to_s, :last_record_id => last_synchronization.try(:last_record_id) }.merge( parameters )
    end

    # Will update all records that have been created, updated or deleted on the remote host
    # since the last successful synchronization.
    #
    # @param [Hash] parameters Parameter options are passed through to {#updated_remotes}. There they are used
    #               as request parameters for remotely requesting the updated records.
    #
    def synchronize!(parameters = {})
      logger.info( "*** Start synchronizing #{table_name} at #{Time.now.to_s :long} ***\n" )
      @sync_count = 0
      begin
        changed_objects = updated_remotes( parameters )
        if changed_objects.any?
          # Do everything within transaction to prevent ending up in half-synchronized situation if an exception is raised.
          transaction { sync_all_records_for(changed_objects) }
        else
          logger.info( " - No #{table_name} to update.\n" )
        end
      rescue => e
        logger.warn( " - Synchronization of #{table_name} failed: #{e} \n #{e.backtrace}" )
      else
        if changed_objects.any?
          last_record_updated_at = time_updated(changed_objects.last)
          last_record_id = changed_objects.last.send(remote_primary_key)
          HasRemote::Synchronization.create!(:model_name => self.name, :last_record_updated_at => last_record_updated_at, :last_record_id => last_record_id)
        end
        logger.info( " - Synchronized #{@sync_count} #{table_name}.\n" ) if @sync_count > 0
      ensure
        logger.info( "*** Stopped synchronizing #{table_name} at #{Time.now.to_s :long} ***\n" )
      end
    end

    # Returns the record for last successful synchronization for this model.
    #
    # @return [Synchronization]
    #
    def last_synchronization
      HasRemote::Synchronization.for(self.name).last
    end

  private

    def sync_all_records_for(resources) #:nodoc:
      resources.each { |resource| sync_all_records_for_resource(resource) }
    end

    def sync_all_records_for_resource(resource) #:nodoc:
      records = find(:all, :conditions => ["#{remote_foreign_key} = ?", resource.send(remote_primary_key)])
      if records.empty?
        create_record_for_resource(resource) unless deleted?(resource)
      else
        records.each { |record| sync_record_for_resource(record, resource) }
      end
    end

    def sync_record_for_resource(record, resource) #:nodoc:
      if deleted?(resource)
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
        @sync_count += 1
        logger.info( was_it_new ? " - Created #{name.downcase} with id #{record.id}.\n" : " - Updated #{name.downcase} with id #{record.id}.\n" )
      end
    end

    def delete_record_for_resource(record, resource) #:nodoc:
      record.destroy
      @sync_count += 1
      logger.info( " - Deleted #{name.downcase} with id #{record.id}.\n" )
    end

    def create_record_for_resource(resource) #:nodoc:
      update_and_save_record_for_resource(new(remote_foreign_key => resource.send(remote_primary_key)), resource)
    end

    def time_updated(resource) #:nodoc:
      (resource.respond_to?(:deleted_at) && resource.deleted_at) ? resource.deleted_at : resource.updated_at
    end

    def deleted?(resource) #:nodoc:
      resource.respond_to?(:deleted_at) && resource.deleted_at && resource.deleted_at <= Time.now
    end

  end
end
