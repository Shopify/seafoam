# frozen_string_literal: true

require "stringio"

require "seafoam"

require "rspec"

require_relative "spec_helpers"

describe Seafoam::JSONWriter do
  describe "#prepare_json" do
    it "transforms a NaN to the string [NaN]" do
      expect(Seafoam::JSONWriter.prepare_json({ a: 1.0, b: Float::NAN, c: 2.0 })).to(eq({ a: 1.0, b: "[NaN]", c: 2.0 }))
    end
  end

  describe "#write" do
    before :each do
      @stream = StringIO.new
      @writer = Seafoam::JSONWriter.new(@stream)
    end

    it "writes to the output object" do
      @writer.write("test_graph", Seafoam::Graph.new(a: 12))

      expected = <<~JSON
        {
          "name": "test_graph",
          "props": {
            "a": 12
          },
          "nodes": [

          ],
          "edges": [

          ]
        }
      JSON

      expect(@stream.string).to(eq(expected))
    end
  end
end
