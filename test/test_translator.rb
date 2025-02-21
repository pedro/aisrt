require "bundler/setup"
require "minitest/test_task"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "translator"

describe Translator do
  it "translates" do
    cli = Minitest::Mock.new

    params = {
      "choices" => [ { "message" => { "content" => '["TRANSLATED1", "TRANSLATED2"]' }}]
    }

    cli.expect(:chat, params) do |args|
      assert_equal "gpt-4o-mini", args[:parameters][:model]
      assert_equal 2, args[:parameters][:messages].size
      true
    end
    
    srt = <<~SRT
      1
      00:00:00,000 --> 00:00:05,000
      TEST1

      2
      00:00:10,000 --> 00:00:20,000
      TEST2
    SRT

    t = Translator.new(cli, srt, {})
    res = t.run
    want = <<~SRT
      1
      00:00:00,000 --> 00:00:05,000
      TRANSLATED1

      2
      00:00:10,000 --> 00:00:20,000
      TRANSLATED2
    SRT
    assert_equal want, res.to_s
  end
end
