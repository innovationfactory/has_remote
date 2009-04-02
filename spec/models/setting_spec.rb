require File.dirname(__FILE__) + '/../spec_helper.rb'

describe HasRemote::Setting do

  describe ".synchronized_at" do

    it "should look up and parse time" do
      setting = mock(:setting)
      setting.should_receive(:value).and_return('01 01 2009')
      HasRemote::Setting.should_receive(:find).and_return(setting)
      HasRemote::Setting.synchronized_at.should == DateTime.parse('01 01 2009')
    end

    it "should return nil" do
      setting = mock(:setting)
      setting.should_receive(:value).and_return(nil)
      HasRemote::Setting.should_receive(:find).and_return(setting)
      HasRemote::Setting.synchronized_at.should be_nil
    end
    
  end
  
  describe ".synchronized_at=" do
    
    it "should save setting as a string" do
      time = Time.now
      setting = mock(:setting)
      setting.should_receive(:update_attributes!).with({:value => time.to_s}).and_return(true)
      HasRemote::Setting.should_receive(:find).and_return(setting)
      HasRemote::Setting.synchronized_at = time
    end
    
  end
  
end