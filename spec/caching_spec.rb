require File.dirname(__FILE__) + '/spec_helper.rb'

context "Given existing remote resources" do
  
  before(:each) do
    User.delete_all
    stub_resource 1, :email => "joeremote@foo.bar"
    stub_resource 2, :email => "jane_remote@foo.bar"
  end
  
  describe "a user" do
    
    it "should return cached attributes" do
      User.should respond_to(:cached_attributes)
      User.cached_attributes.should include(:email)
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
      User.should respond_to(:synchronized_at)
      User.synchronized_at.to_s.should == times.first.to_s
    end
        
    it "should not delegate cached remote attributes" do
      user = User.create! :remote_id => 1
      User::Remote.should_not_receive(:find)
      user.email.should == "joeremote@foo.bar"
    end
    
    it "should update its cached remote attributes on save" do
      user = User.create! :remote_id => 1
      user[:email].should == "joeremote@foo.bar"
      user.update_attributes(:remote_id => 2)
      user[:email].should == "jane_remote@foo.bar"   
    end

    it "should not update its cached remote attributes if skip_update_cache is true" do
      user = User.create! :remote_id => 1, :skip_update_cache => true
      user[:email].should == nil
    end
    
  end

  describe "synchronization" do
  
    describe "for the User model" do
    
      describe "with updated and deleted remotes" do
        
        before(:each) do
          @user_1, @user_2, @user_3 = User.create!(:remote_id => 1), User.create!(:remote_id => 2), User.create!(:remote_id => 3)
        
          @yesterday = DateTime.parse 1.day.ago.to_s
        
          resources = [
            mock(:user, :id => 1, :email => "changed@foo.bar", :updated_at => @yesterday),
            mock(:user, :id => 2, :email => "altered@foo.bar", :updated_at => 2.days.ago, :deleted_at => nil),
            mock(:user, :id => 3, :email => "deleted@foo.bar", :updated_at => 2.days.ago, :deleted_at => 2.days.ago),
            mock(:user, :id => 4, :email => "new@foo.bar", :updated_at => @yesterday),
            mock(:user, :id => 5, :email => "new-deleted@foo.bar", :updated_at => 2.days.ago, :deleted_at => 2.days.ago),
          ]
          User.stub!(:changed_remotes_since).and_return(resources)
        
          lambda { User.synchronize! }.should change(HasRemote::Synchronization, :count).by(1)
        end
        
        it "should keep track of the last synchronization" do
          HasRemote::Synchronization.for("HasRemoteSpec::User").latest_change.should == @yesterday
        end
    
        it "should update changed users" do
          @user_1.reload[:email].should == "changed@foo.bar"
          @user_2.reload[:email].should == "altered@foo.bar"
        end
      
        it "should destroy deleted users" do
          User.exists?(@user_3).should be_false
        end
      
        it "should create added users" do
          User.exists?(:remote_id => 4).should be_true
        end
        
        it "should not create deleted users" do
          User.exists?(:remote_id => 5).should be_false
        end
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
            
            User.synchronize!
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
  
  describe "synchronizing new cheeses" do
    before do
      resources = [
        mock(:cheese, :id => 1, :name => "Brie", :updated_at => Date.yesterday)
      ]
      Cheese.stub!(:changed_remotes_since).and_return(resources)
      lambda{ Cheese.synchronize! }.should change(Cheese, :count).from(0).to(1)
    end
    
    after { Cheese.delete_all }
        
    it "should populate the local 'maturity' attribute with its default database value" do
      Cheese.first.maturity.should == 5
    end
    
    it "should populate the local 'smell' attribute with the value set inside of a before_validation callback" do
      Cheese.first.smell.should == 5 * 10 
    end
    
  end
  
end

def stub_resource(id, attrs)
  resource = mock(:user, {:id => id}.merge(attrs))
  User::Remote.stub!(:find).with(id).and_return(resource)
  resource
end