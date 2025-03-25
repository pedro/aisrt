require "bundler/setup"

require "csv"
require "dotenv/load"
require "openai"
require "optparse"

require_relative "translator"

options = {
  from: "en",
  to: "en",
  model: "gpt-4o-mini",
}

OptionParser.new do |opts|
  opts.banner = "Usage: aisrt.rb [options]"

  opts.on("-s", "--srt SRT", "SRT file") do |o|
    options[:file] = o
  end

  opts.on("--from LANG", "LANG the subtitle is in. Defaults to #{options[:from]}") do |o|
    options[:from] = o
  end

  opts.on("--to LANG", "LANG to translate to. Defaults to #{options[:to]}") do |o|
    options[:to] = o
  end

  opts.on("--model MODEL", "Model to use. Defaults to #{options[:model]}") do |o|
    opts[:model] = o
  end
end.parse!

unless options[:file]
  puts "Missing --srt"
  exit 1
end

client = OpenAI::Client.new(
  access_token: ENV["OPENAI_API_KEY"],
  log_errors: true,
  request_timeout: 120,
)

t = Translator.new(client, File.read(options[:file]), options)
srt = t.run

source = File.basename(options[:file])
output = source.sub(/\.[\w-]+\.srt$/, ".#{options[:to]}.srt")
if output == source
  output = "translated-#{source}"
end

File.write(output, srt.to_s)
puts "Translated subtitles written to #{output}"
