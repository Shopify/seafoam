# frozen_string_literal: true

require "seafoam"

require "rspec"

describe Seafoam::Passes do
  describe "#apply" do
    it "asks passes if they apply" do
      check_applied = false

      Class.new(Seafoam::Pass) do
        singleton_class.define_method(:applies?) do |_graph|
          check_applied = true
          false
        end
      end

      Seafoam::Passes.apply(Seafoam::Graph.new)
      expect(check_applied).to(be(true))
    end

    it "runs passes that apply" do
      check_applied = false

      Class.new(Seafoam::Pass) do
        singleton_class.define_method(:applies?) do |_graph|
          true
        end

        define_method(:apply) do |_graph|
          check_applied = true
        end
      end

      Seafoam::Passes.apply(Seafoam::Graph.new)
      expect(check_applied).to(be(true))
    end
  end

  describe "#passes" do
    it "returns the standard passes" do
      passes = Seafoam::Passes.passes
      expect(passes).to(include(Seafoam::Passes::FallbackPass))
      expect(passes).to(include(Seafoam::Passes::GraalPass))
    end

    it "returns custom passes" do
      custom_pass = Class.new(Seafoam::Pass) do
        def self.applies?(_graph)
          false
        end
      end
      passes = Seafoam::Passes.passes
      expect(passes).to(include(custom_pass))
    end

    it "returns the FallbackPass pass last" do
      passes = Seafoam::Passes.passes
      expect(passes.last).to(eq(Seafoam::Passes::FallbackPass))
    end
  end
end
