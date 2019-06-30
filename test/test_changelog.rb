# frozen_string_literal: true
require_relative 'helper'

describe Prop::VERSION do
  it "should always add a changelog while bumping versions" do
    changes = File.read("#{File.dirname(__FILE__)}/../Changelog.md")
    assert changes.include?("## #{Prop::VERSION}"), "version #{Prop::VERSION}"\
      "not found in Changelog.md, Please update the Changelog file"
  end
end
