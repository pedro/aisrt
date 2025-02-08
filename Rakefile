require "bundler/setup"
require "rake"
require "minitest/test_task"

Minitest::TestTask.create

desc "Run test on changes"
task :guard do
  exec "bundle exec guard --no-interactions"
end

task :default => :test
