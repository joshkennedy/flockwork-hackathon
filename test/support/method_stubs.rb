# Swaps one class method for the duration of the block, then restores the original.
module MethodStubs
  def stub_method(target, name, callable)
    original = target.method(name)
    target.define_singleton_method(name) { |*args, **kwargs, &block| callable.call(*args, **kwargs, &block) }
    yield
  ensure
    target.define_singleton_method(name, original)
  end
end
