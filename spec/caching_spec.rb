require File.dirname(__FILE__) + '/spec_helper.rb'

describe "Given existing remote resources" do

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
      User::Remote.should_receive(:find).with(:all,{:from => :updated, :params=>{:since=>time.to_s, :last_record_id=>nil}}).once.and_return([user_1, user_2])

      User.should respond_to(:updated_remotes)
      User.updated_remotes(:since => time.to_s).should include(user_1, user_2)
    end

    it "should find last synchronization" do
      times = []
      3.downto(1) do |i|
        HasRemote::Synchronization.create!(:model_name => 'User', :last_record_updated_at => i.days.ago, :last_record_id => i)
      end
      User.should respond_to(:last_synchronization)
      sync = User.last_synchronization
      sync.last_record_updated_at.to_s.should == 1.day.ago.to_s
      sync.last_record_id.should == 1
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
          @yesterday = 1.day.ago
          @user_1, @user_2 = User.create!(:remote_id => 1), User.create!(:remote_id => 2)

          resources = [
            mock(:user, :id => 1, :email => "altered@foo.bar", :updated_at => 2.days.ago, :deleted_at => nil),
            mock(:user, :id => 2, :email => "deleted@foo.bar", :updated_at => 2.days.ago, :deleted_at => 2.days.ago),
            mock(:user, :id => 3, :email => "new-deleted@foo.bar", :updated_at => 2.days.ago, :deleted_at => 2.days.ago),
            mock(:user, :id => 4, :email => "new@foo.bar", :updated_at => @yesterday),
          ]
          User.stub!(:updated_remotes).and_return(resources)

          lambda { User.synchronize! }.should change(HasRemote::Synchronization, :count).by(1)
        end

        it "should keep track of the last synchronized record" do
          sync = HasRemote::Synchronization.for("User").last

          sync.last_record_updated_at.should == @yesterday
          sync.last_record_id.should == 4
        end

        it "should update changed users" do
          @user_1.reload[:email].should == "altered@foo.bar"
        end

        it "should destroy deleted users" do
          User.exists?(@user_2).should be_false
        end

        it "should create added users" do
          User.exists?(:remote_id => 4).should be_true
        end

        it "should not create deleted users" do
          User.exists?(:remote_id => 3).should be_false
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

            User.stub!(:updated_remotes).and_return(resources)

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
      Cheese.stub!(:updated_remotes).and_return(resources)
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