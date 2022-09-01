# frozen_string_literal: true

task default: [:specs, :rubocop]

task :specs do
  sh "rspec", "spec"
end

task :rubocop do
  sh "rubocop", "bin", "demos", "lib", "spec"
end
