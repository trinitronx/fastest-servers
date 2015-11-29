require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/*/*_spec.rb'
end

RSpec::Core::RakeTask.new(:exclude_slow) do |t|
  t.pattern = 'spec/*/*_spec.rb'
  t.rspec_opts = '--tag ~slow'
end
