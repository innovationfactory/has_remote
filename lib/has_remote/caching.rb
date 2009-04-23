module HasRemote
  
  # Contains class methods regarding local caching and synchronization.
  #
  # === Synchronization examples
  #
  # Update all cached attributes for all models that have a remote:
  #  HasRemote.update_cached_attributes!
  #
  # Update all cached attributes only for users:
  #  User.update_cached_attributes!
  #
  # You can also update a single record:
  #  @user.update_cached_attributes!
  #
  # You could make your application call these methods whenever you need to be sure
  # your cache is up to date.
  #
  module Caching

    # Returns an array of all attributes that are locally cached.
    #
    def cached_attributes
      @cached_attributes ||= []
    end    
    
    # Returns all remote objects that have been changed since the given time.
    #
    # This is used by the <tt>update_cached_attributes!</tt> class method. By default
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
    
    # Will update all records that have changed on the remote host
    # since the last successful synchronization.
    #
    def update_cached_attributes!
      logger.info( "*** Start synchronizing #{table_name} at #{Time.now.to_s :long} ***\n" )
      @update_count = 0
      begin
        changed_objects = changed_remotes_since( cache_updated_at )
        if changed_objects.any?
          transaction { update_all_records_for(changed_objects) }
        else
          logger.info( " - No #{table_name} to update.\n" )
        end
      rescue => e
        logger.warn( " - Synchronization of #{table_name} failed: #{e} \n #{e.backtrace}" )
      else
        self.cache_updated_at = changed_objects.map(&:updated_at).sort.last if changed_objects.any?  
        logger.info( " - Updated #{@update_count} #{table_name}.\n" ) if @update_count > 0
      ensure
        logger.info( "*** Stopped synchronizing #{table_name} at #{Time.now.to_s :long} ***\n" )
      end
    end
    
    # Time of the last successful synchronization.
    #
    def cache_updated_at
      HasRemote::Synchronization.for(self.name).latest_change
    end
    
  private

    def cache_updated_at=(time) #:nodoc:
      HasRemote::Synchronization.create!(:model_name => self.name, :latest_change => time)
    end

    def update_all_records_for(resources) #:nodoc:
      resources.each { |resource| update_all_records_for_resource(resource) }
    end
    
    def update_all_records_for_resource(resource) #:nodoc:
      records = find(:all, :conditions => ["#{remote_foreign_key} = ?", resource.send(remote_primary_key)])
      unless records.empty?
        records.each { |record| update_record_for_resource(record, resource) }
      else
        logger.info( " - No local #{name.downcase} has remote with id #{resource.send(remote_primary_key)}.\n" )
      end
    end
    
    def update_record_for_resource(record, resource) #:nodoc:
      cached_attributes.each do |remote_attr, local_attr|
        record.send :write_attribute, local_attr, resource.send(remote_attr) 
      end
      if record.save!
        @update_count += 1
        logger.info( " - Updated #{name.downcase} with id #{record.id}.\n" )
      end
    end

  end  
end