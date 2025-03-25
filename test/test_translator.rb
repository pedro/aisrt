require "bundler/setup"
require "minitest/test_task"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "translator"

system "clear" # really this should be in guard but having trouble with it

describe Translator do
  it "translates" do
    cli = setup_cli(["TRANSLATED1", "TRANSLATED2"]) do |model, js|
      assert_equal "gpt-4o-mini", model
      assert_equal ["TEST1", "TEST2"], js
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

  it "deals with shit responses" do
    responses = [
      %Q(\n["TRANSLATED1"]),
      %Q(```\n["TRANSLATED1"]\n```),
      %Q(```json\n["TRANSLATED1"]\n```),
    ]

    responses.each do |variant|
      cli = setup_cli(variant) do |model, js|
        assert_equal ["TEST1"], js
      end
      
      srt = <<~SRT
        1
        00:00:00,000 --> 00:00:05,000
        TEST1
      SRT

      t = Translator.new(cli, srt, {})
      res = t.run
      want = <<~SRT
        1
        00:00:00,000 --> 00:00:05,000
        TRANSLATED1
      SRT
      assert_equal want, res.to_s
    end
  end

  it "combines sentences in succession" do
    cli = setup_cli(["ABC1 DEF1 very long line that will be split somehow1", "END1"]) do |model, js|
      assert_equal ["ABC DEF very long line that will be split somehow", "END"], js
    end
    
    srt = <<~SRT
      1
      00:00:00,000 --> 00:00:05,000
      ABC

      2
      00:00:05,000 --> 00:00:10,000
      DEF

      3
      00:00:10,000 --> 00:00:15,000
      very long line that will be split somehow

      3
      00:00:20,000 --> 00:00:25,000
      END
    SRT

    t = Translator.new(cli, srt, { max_len: 5})
    res = t.run
    want = <<~SRT
      1
      00:00:00,000 --> 00:00:03,000
      ABC1
      DEF1

      2
      00:00:03,000 --> 00:00:06,000
      very
      long

      3
      00:00:06,000 --> 00:00:09,000
      line
      that

      4
      00:00:09,000 --> 00:00:12,000
      will
      be

      5
      00:00:12,000 --> 00:00:15,000
      split
      somehow1

      6
      00:00:20,000 --> 00:00:25,000
      END1
    SRT
    assert_equal want, res.to_s
  end

  it "breaks continuous sentences" do
    breaks = [
      "♪",         # not translateable
      "[FOO] BAR", # starts with a bracket
    ]

    breaks.each do |br|
      cli = setup_cli(["ABC1", br])

      srt = <<~SRT
        1
        00:00:00,000 --> 00:00:05,000
        ABC

        2
        00:00:05,000 --> 00:00:10,000
        #{br}
      SRT

      t = Translator.new(cli, srt, {})
      res = t.run
      want = <<~SRT
        1
        00:00:00,000 --> 00:00:05,000
        ABC1

        2
        00:00:05,000 --> 00:00:10,000
        #{br}
      SRT
      assert_equal want, res.to_s
      end
  end
end

def setup_cli(response)
  cli = Minitest::Mock.new

  if !response.is_a?(String)
    response = JSON.generate(response)
  end

  params = {
    "choices" => [ { "message" => { "content" => response }}]
  }

  cli.expect(:chat, params) do |args|
    msgs = args[:parameters][:messages]
    if msgs.size != 2
      raise "expected 2 messages, got #{msgs.size}: #{msgs.inspect}"
    end
    last = args[:parameters][:messages].last[:content].split("\n").last
    js = JSON.parse(last)
    yield(args[:parameters][:model], js) if block_given?
    true
  end

  return cli
end