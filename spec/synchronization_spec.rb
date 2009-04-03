require File.dirname(__FILE__) + '/spec_helper.rb'

describe HasRemote::Synchronization do
  
  subject { HasRemote::Synchronization.new }
    
  it { should validate_presence_of(:model_name) }
  it { should validate_presence_of(:latest_change) }
  it { should have_named_scope("for('User')") }

end