require File.expand_path('spec/rails_app/config/environment', File.dirname(__FILE__))
require 'rdoc/task'

desc 'Default: run test suite.'
task :default => :spec

desc 'Generate documentation for the devise-radius-authenticatable gem.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Devise Radius Authenticatable'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.md')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

RailsApp::Application.load_tasks
