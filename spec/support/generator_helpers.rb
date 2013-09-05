module GeneratorHelpers
  DESTINATION_PATH = File.expand_path("../../../tmp", __FILE__)
  FIXTURES_PATH = File.expand_path("../../fixtures", __FILE__)

  def prepare_devise
    initializers_path = File.join(DESTINATION_PATH, 'config/initializers')
    FileUtils.mkpath(initializers_path)
    FileUtils.cp(File.join(FIXTURES_PATH, 'devise.rb'), initializers_path)
  end
end

RSpec::configure do |c|
  c.include GeneratorHelpers, :type => :generator, :example_group => {
    :file_path => /spec[\\\/]generators/
  }
end
