class Cheese < ActiveRecord::Base
  validates_presence_of :maturity, :smell
  has_remote :site => "http://dummy.local"
  before_validation :set_smell, :on => :create

  protected

  def set_smell
    self.smell = self.maturity * 10 if self.smell.nil?
  end
end