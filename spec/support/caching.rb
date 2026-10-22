RSpec.configure do |config|
  config.before(:each, :caching) do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end
end
