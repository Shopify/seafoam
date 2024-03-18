# frozen_string_literal: true

require("bundler/gem_tasks")

task default: [:specs, :rubocop]

task :specs do
  sh "rspec", "spec"
end

task :rubocop do
  sh "rubocop", "bin", "demos", "lib", "spec", "tools/generate-examples.rb"
end
