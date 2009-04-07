require File.dirname(__FILE__) + '/spec_helper.rb'

describe HasRemote do
  it "should know about registered models" do
    HasRemote.should respond_to(:models)
    HasRemote.models.should include(User, Book)
  end
end

describe "A model thaht has a remote" do
 
  it "should respond to 'remote_class' and 'remote_key'" do
    User.should respond_to(:remote_class, :remote_key)
    User.remote_class.should == User::Remote
    User.remote_key.should == :remote_id
  end
  
  it "should set remote class' configuration" do
     User.remote_class.site.should_not be_nil
     User.remote_class.element_name.should == "user"
  end
  
  it "should return remote attributes" do
    User.remote_attributes.should include(:name, :email)
  end

  describe "instances" do
    
    before(:each) do
      @user = User.new
      @user.remote_id = 1
    end
    
    it "should have a generated remote" do
      User::Remote.should_receive(:find).any_number_of_times.with(1).and_return( mock(:resource, :name => "John") )
      
      @user.should respond_to(:remote)
      @user.remote.should respond_to(:name)
      @user.has_remote?.should be_true
    end
    
    it "should use a custom remote key" do
      Book.remote_key.should == :custom_remote_id
    end
    
    it "should have a custom remote" do
      @book = Book.new
      @book.custom_remote_id = 1
      
      HasRemoteSpec::RemoteBook.should_receive(:find).any_number_of_times.with(1).and_return( mock(:resource, :title => "Ruby for Rails") )
      
      @book.should respond_to(:remote)
      @book.remote.should respond_to(:title)
      @book.has_remote?.should be_true
    end
    
    it "should delegate remote attribute" do
      User::Remote.should_receive(:find).any_number_of_times.with(1).and_return( mock(:resource, :name => "John") )
      
      @user.should respond_to(:name)
      @user.name.should == "John"
    end
    
    it "should not have a remote" do
      User::Remote.should_receive(:find).any_number_of_times.with(1).and_raise "not found"
      @user.remote.should be_nil
      @user.has_remote?.should be_false
    end
    
    context "without a remote" do
      before(:each) do
        @user.remote_id = nil
      end
      
      it "should return nil for remote attributes" do
        @user.remote.should be_nil
        @user.name.should be_nil
      end
    end
  end
  
end