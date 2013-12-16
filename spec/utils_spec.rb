require_relative 'support/spec_helper'

include Utils

describe Utils do
  describe ".eval_metadata" do
    let(:response_metadata) do
      "name             'test_meta'\n" \
      "maintainer       'Kitchen Inspector'\n" \
      "maintainer_email 'example@fake.com'\n" \
      "license          'All rights reserved'\n" \
      "description      'Installs/Configures test_meta'\n" \
      "long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))\n" \
      "version          '0.10.2'\n" \
      "depends 'apache2', '= 1.8.2'\n" \
      "depends 'postgresql', '= 3.0.5'"
    end

    it "generates a valid Metadata" do
      metadata = eval_metadata response_metadata
      expect(metadata.version).to eq("0.10.2")
    end

    it "generates a Metadata with filtered fields" do
      metadata = eval_metadata response_metadata
      expect(metadata.description).to eq("A fabulous new cookbook")
    end
  end
end
