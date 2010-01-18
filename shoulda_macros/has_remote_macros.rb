module HasRemoteMacros

  def should_have_remote(&block)
    klass = model_class
    should "have remote resources" do
      assert HasRemote.models.include?(klass)
    end
  end

  def should_have_remote_attribute(attr_name, options = {})
    klass = model_class
    should "have remote attribute #{attr_name}" do
      assert klass.remote_attributes.include?(attr_name)
      assert klass.cached_attributes.include?(attr_name) if options[:local_cache]
      assert klass.new.respond_to?(options[:as] || attr_name)
    end
  end

end

Test::Unit::TestCase.extend HasRemoteMacros