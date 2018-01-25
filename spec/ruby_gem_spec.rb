require 'spec_helper'

describe Gatecoin::API do
  subject(:ruby_gem) { Gatecoin::API.new }

  describe ".new" do
    it "makes a new instance" do
      expect(ruby_gem).to be_a Gatecoin::API
    end
  end
end
