# Execute the actual Fastfile with fake external boundaries; no Fastlane or Play access.
require 'minitest/autorun'
class FastlaneBoundaryTest < Minitest::Test
  class Rejected < StandardError; end
  module UI
    def self.message(*); end
    def self.user_error!(message); raise Rejected, message; end
  end
  class Harness
    attr_reader :lanes, :external_calls
    def initialize; @lanes = {}; @external_calls = []; end
    def default_platform(*); end
    def platform(*); yield; end
    def desc(*); end
    def lane(name, &block); @lanes[name] = block; end
    def upload_to_play_store(*args); @external_calls << [:upload, args]; end
    def sh(*args); @external_calls << [:build, args]; end
  end
  def test_every_legacy_lane_rejects_every_candidate_before_external_action
    %w[missing-gates wrong-hash smoke-artifact invalid-promotion valid-local-artifact].each do |candidate|
      harness = Harness.new
      harness.instance_eval(File.read(ENV.fetch('FASTFILE_UNDER_TEST', File.expand_path('../android/fastlane/Fastfile', __dir__))))
      assert_equal [:internal, :promote_to_production], harness.lanes.keys
      harness.lanes.each_value do |run|
        error = assert_raises(Rejected, candidate) { run.call }
        assert_includes error.message, 'disabled'
        assert_empty harness.external_calls
      end
    end
  end
end
