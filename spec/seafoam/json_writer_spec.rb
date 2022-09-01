# frozen_string_literal: true

require "seafoam"

require "rspec"

require_relative "spec_helpers"

describe Seafoam::JSONWriter do
  describe "#prepare_json" do
    it "transforms a NaN to the string [NaN]" do
      expect(Seafoam::JSONWriter.prepare_json({ a: 1.0, b: Float::NAN, c: 2.0 })).to(eq({ a: 1.0, b: "[NaN]", c: 2.0 }))
    end
  end
end
