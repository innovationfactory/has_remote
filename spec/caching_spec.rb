require File.dirname(__FILE__) + '/spec_helper.rb'

context "Given existing remote resources" do
  
  before(:each) do
    User.delete_all
    stub_resource 1, :email => "joeremote@foo.bar"
    stub_resource 2, :email => "jane_remote@foo.bar"
  end
  
  describe "a user" do
    
    it "should respond to :cached_attributes"
    it "should respond to :changed_remotes_since"
    it "should respond to :cache_updated_at"
  
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
      
      it "should fail save"
    
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
  resource = mock(:user, attrs)
  User::Remote.stub!(:find).with(id).and_return(resource)
end