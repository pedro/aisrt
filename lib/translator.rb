require "json"
require "srt"

class Translator
  def initialize(client, contents, options)
    @client = client
    @contents = contents
    @options = options
  end

  def run
    srt = SRT::File.parse(@contents)
    
    unique_texts = srt.lines.map{ |l| id(l) }.select { |t| t.match?(/[A-Za-z]/) }
    translation_map = translate(unique_texts)
    
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

    srt
  end

  def translate(texts, batch_size: 100)
    translations = {}
  
    batches = texts.each_slice(batch_size)
    puts "batches: #{batches.size}"
  
    batches.each do |batch|
      prompt = <<~PROMPT
        Translate the following subtitles from #{@options[:from]} to #{@options[:to]}.
        Subtitles are provided as a JSON array. each entry corresponds to a string to be translated.
        Return a JSON array where each entry corresponds to the translated string.
        Do not include any extra text.
  
        Subtitles:
        #{JSON.generate(batch)}
      PROMPT
  
      response = @client.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: "You're a professional translator tasked with translating subtitles for movies and TV shows. Provide accurate translations while preserving context and tone." },
            { role: "user", content: prompt }
          ]
        }
      )
  
      puts "got: #{response.inspect}"
      raw = response.dig("choices", 0, "message", "content").sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, "")
      result = JSON.parse(raw)

      result.each_with_index do |t, i|
        original_text = batch[i]
        translations[original_text] = t.strip
      end
    end
    translations
  end

  def id(line)
    line.text.join(" ")
  end
end
