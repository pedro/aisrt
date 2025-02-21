require "json"
require "srt"

TEXT = /[A-Za-z]/

class Translator
  def initialize(client, contents, options)
    @client = client
    @contents = contents
    @options = options
  end

  def run
    srt = SRT::File.parse(@contents)

    groups = srt.lines.slice_when do |prev, curr|
      str1 = prev.text.join(" ")
      str2 = curr.text.join(" ")
      curr.start_time != prev.end_time || !str1.match?(TEXT) || !str2.match?(TEXT) || str2.start_with?("[")
    end.to_a

    sentences = groups.map { |g| g.map { |line| id(line) }.join(" ") }.select { |t| t.match?(TEXT) }
    translation_map = translate(sentences)

    idx = 0
    new_lines = groups.map do |group|
      sentence = group.map { |line| id(line) }.join(" ")
      if tr = translation_map[sentence]
        res = tr.split.reduce([]) do |lines, word|
          if lines.empty? || lines.last.length + word.length + 1 > (@options[:max_len] || 42)
            lines << word
          else
            lines[-1] += " " + word
          end
          lines
        end

        at = group.first.start_time
        total_time = group.last.end_time - at
        time_per_word = total_time / tr.split.size

        res.each_slice(2).map do |lines|
          dur = lines.join(" ").split.size * time_per_word
          at += dur
          SRT::Line.new(
            sequence: idx += 1,
            start_time: at - dur,
            end_time: at,
            text: lines,
          )
        end
      else
        group.map { |l| l.sequence = idx += 1; l }
      end
    end

    srt.lines = new_lines.flatten
    srt
  end

  def translate(texts, batch_size: 100)
    translations = {}
  
    batches = texts.each_slice(batch_size)
  
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
