require "bundler/setup"

require "csv"
require "dotenv/load"
require "openai"
require "optparse"
require "json"
require "srt"

options = {
  from: "en",
  to: "en",
}

OptionParser.new do |opts|
  opts.banner = "Usage: aisrt.rb [options]"

  opts.on("-s", "--srt SRT", "SRT file") do |o|
    options[:file] = o
  end

  opts.on("--from LANG", "LANG the subtitle is in. Defaults to en") do |o|
    options[:from] = o
  end

  opts.on("--to LANG", "LANG to translate to. Defaults to en") do |o|
    options[:to] = o
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

# Batch translate unique texts that need translation
def batch_translate_texts(client, options, texts, batch_size: 100)
  translations = {}

  batches = texts.each_slice(batch_size)
  puts "batches: #{batches.size}"

  batches.each do |batch|
    prompt = <<~PROMPT
      Translate the following subtitles from #{options[:from]} to #{options[:to]}. 
      Each subtitle is provided as a JSON object with an "id" and "text".
      Return a JSON array where each object contains the same "id" and the translated text under "translation".
      Do not include any extra text.

      Subtitles:
      #{JSON.pretty_generate(batch.map.with_index { |t, i| { id: i, text: t } })}
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: "You're a professional translator tasked with translating subtitles for movies and TV shows. Provide accurate translations while preserving context and tone." },
          { role: "user", content: prompt }
        ]
      }
    )

    raw = response.dig("choices", 0, "message", "content").sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, "")
    result = JSON.parse(raw)
    puts "got batch #{result.size}"
    result.each_with_index do |item, idx|
      original_text = batch[item["id"]]
      translations[original_text] = item["translation"].strip
    end
  end
  translations
end

def id(line)
  return line.text.join(" ")
end

srt_data = File.read(options[:file])
srt = SRT::File.parse(srt_data)

unique_texts = srt.lines.map{ |l| id(l) }.select { |t| t.match?(/[A-Za-z]/) }
translation_map = batch_translate_texts(client, options, unique_texts)

srt.lines.each_with_index do |l, i|
  x = id(l)
  if translated = translation_map[x]
    if translated.size > 42
      parts = translated.split(" ")
      mid = parts.size / 2
      translated = parts[0..mid].join(" ") + "\n" + parts[mid+1..-1].join(" ")
    end
    l.text = translated.split("\n")
  end
end

# Write out the translated SRT
output_file = "translated_#{File.basename(options[:file])}"
File.write(output_file, srt.to_s)
puts "Translated subtitles written to #{output_file}"
