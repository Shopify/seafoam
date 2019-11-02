require 'seafoam'

require 'rspec'

require_relative '../spec_helpers'

describe Seafoam::Annotators::GraalAnnotator do
  it 'applies to Graal graphs' do
    expect(Seafoam::Annotators::GraalAnnotator.applies?(Seafoam::SpecHelpers.example_graph('fib-java', 0))).to be true
  end

  it 'does not apply to Truffle trees' do
    expect(Seafoam::Annotators::GraalAnnotator.applies?(Seafoam::SpecHelpers.example_graph('fib-js', 0))).to be false
  end

  it 'applies to Truffle graphs' do
    expect(Seafoam::Annotators::GraalAnnotator.applies?(Seafoam::SpecHelpers.example_graph('fib-js', 2))).to be true
  end
end
