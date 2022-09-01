# frozen_string_literal: true

task default: :specs

task :specs do
  sh "rspec", "spec"
end

task :rubocop do
  sh "rubocop", "bin", "demos", "lib", "spec", "tools"
end
