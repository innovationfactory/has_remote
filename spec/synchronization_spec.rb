require File.dirname(__FILE__) + '/spec_helper.rb'

describe HasRemote::Synchronization do

  subject { HasRemote::Synchronization.new }

  it { should validate_presence_of(:model_name) }
  it { should validate_presence_of(:last_record_updated_at) }
  it { should validate_presence_of(:last_record_id) }

  describe "named scope 'for'" do
    before do
      HasRemote::Synchronization.delete_all
      @user_synchronization = HasRemote::Synchronization.create! :model_name => 'User', :last_record_updated_at => 1.day.ago, :last_record_id => 1
      @book_synchronization = HasRemote::Synchronization.create! :model_name => 'Book', :last_record_updated_at => 1.day.ago, :last_record_id => 2
    end

    it "should return synchronization records scoped by model_name" do
      HasRemote::Synchronization.for('User').should == [@user_synchronization]
    end
  end

end