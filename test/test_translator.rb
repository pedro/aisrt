require "bundler/setup"
require "minitest/test_task"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "translator"

describe Translator do
  it "translates" do
    cli = Minitest::Mock.new
    cli.expect(:chat, { "choices" => [ { "message" => { "content" => "{}" }}]}) do |args|
      assert_equal "gpt-4o-mini", args[:parameters][:model]
      assert_equal 2, args[:parameters][:messages].size
      true
    end
    
    srt = <<~SRT
      1
      00:00:00,000 --> 00:00:05,000
      TEST
    SRT

    t = Translator.new(cli, srt, {})
    res = t.run
    assert_equal "1\n00:00:00,000 --> 00:00:05,000\nTEST\n", res.to_s
  end
end
