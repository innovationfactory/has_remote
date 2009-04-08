require File.dirname(__FILE__) + '/spec_helper.rb'

context "Given existing remote resources" do
  
  before(:each) do
    User.delete_all
    stub_resource 1, :email => "joeremote@foo.bar"
    stub_resource 2, :email => "jane_remote@foo.bar"
  end
  
  describe "a user" do
    
    it "should return cached_attributes" do
      User.should respond_to(:cached_attributes)
      User.cached_attributes.should include([:email, :email])
    end
    
    it "should return changed remotes since yesterday" do
      user_1, user_2 = mock(:user), mock(:user)
      time = 1.day.ago
      User::Remote.should_receive(:find).with(:all,{:from => :updated, :params=>{:since=>time.to_s}}).once.and_return([user_1, user_2])
      
      User.should respond_to(:changed_remotes_since)
      User.changed_remotes_since(time).should include(user_1, user_2)
    end
    
    it "should find last synchronization time" do
      times = []
      1.upto(3) do |i|
        times << i.days.ago
        HasRemote::Synchronization.create(:model_name => 'HasRemoteSpec::User', :latest_change => times.last)
      end
      User.should respond_to(:cache_updated_at)
      User.cache_updated_at.to_s.should == times.first.to_s
    end
  
    it "should update its remote attributes when saved" do
      user = User.new :remote_id => 1
      user[:email].should be_nil
   
      user.save!
      user[:email].should == "joeremote@foo.bar"
    end

    it "should update its remote attributes when created and updated" do
      user = User.create! :remote_id => 1
      user[:email].should == "joeremote@foo.bar"
      user.update_attributes(:remote_id => 2)
      user[:email].should == "jane_remote@foo.bar"   
    end
  end

  describe "synchronization" do
  
    describe "for the User model" do
    
      it "should update all users" do
        user_1, user_2 = User.create!(:remote_id => 1), User.create!(:remote_id => 2)
        
        yesterday = DateTime.parse 1.day.ago.to_s
        
        resources = [
          mock(:user, :id => 1, :email => "changed@foo.bar", :updated_at => yesterday),
          mock(:user, :id => 2, :email => "altered@foo.bar", :updated_at => 2.days.ago)
        ]
        User.stub!(:changed_remotes_since).and_return(resources)
        
        lambda { User.update_cached_attributes! }.should change(HasRemote::Synchronization, :count).by(1)

        user_1.reload[:email].should == "changed@foo.bar"
        user_2.reload[:email].should == "altered@foo.bar"

        HasRemote::Synchronization.for("HasRemoteSpec::User").latest_change.should == yesterday
      end
      
      describe "that fails" do
        
        before(:each) do
          
          @failure = lambda {
            user_1, user_2 = User.create!(:remote_id => 1), User.create!(:remote_id => 2)

            yesterday = DateTime.parse 1.day.ago.to_s

            resources = [
              mock(:user, :id => 1, :email => "changed@foo.bar", :updated_at => yesterday),
              mock(:user, :id => 2, :email => "altered@foo.bar", :updated_at => 2.days.ago)
            ]
            
            User.stub!(:changed_remotes_since).and_return(resources)
            
            resources.last.should_receive(:send).and_raise "All hell breaks loose" # Raise when attr is read from resource 2.
            
            User.update_cached_attributes!
          }
        end
        
        it "should do it silently" do
          @failure.should_not raise_error
        end
      
        it "should not create a synchronization record" do
          @failure.should_not change(HasRemote::Synchronization, :count)
        end
        
      end
    
    end
  
    describe "for a single user" do
    
      it "should update the user" do
        user = User.create! :remote_id => 1
        user[:email].should == "joeremote@foo.bar"
        
        stub_resource 1, :email => "changed@foo.bar"
        
        user.update_cached_attributes!
        user[:email].should == "changed@foo.bar"
      end
    
    end
  
  end
  
end

def stub_resource(id, attrs)
  resource = mock(:user, {:id => id}.merge(attrs))
  User::Remote.stub!(:find).with(id).and_return(resource)
  resource
end