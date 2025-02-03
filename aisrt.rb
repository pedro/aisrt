require "bundler/setup"

require "csv"
require "dotenv/load"
require "openai"
require "optparse"
require "json"

options = {
  from: "en",
  to: "en",
}

OptionParser.new do |opts|
  opts.banner = "Usage: aisrt.rb [options]"

  opts.on("-s", "--srt SRT", "SRT file") do |f|
    options[:file] = f
  end

  opts.on("--from LANG", "LANG the subtitle is in. Defaults to en") do |h|
    options[:from] = h
  end
  opts.on("--to LANG", "LANG to translate to. Defaults to en") do |h|
    options[:to] = h
  end
end.parse!

unless options[:file]
  puts "Missing --srt"
  exit 1
end

puts options.inspect
exit 0

values = []
headerIndex = nil

CSV.foreach(options[:file]).each_with_index do |row, i|
  if i == 0
    m = row.each_with_index.find { |h, i| h.strip == options[:header] }
    unless m 
      puts "Header not found.\nAvailable:\n\n#{row.join("\n")}"
      exit 1
    end
    headerIndex = m.last
    next
  end

  v = row[headerIndex]
  values << (v.is_a?(String) ? v.gsub("\n", " ") : nil)
end


client = OpenAI::Client.new(
  access_token: ENV["OPENAI_API_KEY"],
  log_errors: true,
)

batches = [values.reject(&:nil?)[0, 5]]

system = %{
  Você é um assistente profissional para codificar questões abertas em
  questionários de pesquisa de mercado. Você vai receber uma série de
  respostas dos entrevistados, e deve escolher uma lista de temas que melhor
  os representam.

  Esta pesquisa foi feita em uma feira de calçados chamada BFSHOW, solicitada
  pelos organizadores do evento e respondida pelos expositores. A idéia é ouvir
  deles o que acharam do evento e como podem melhorar.

  Você vai receber uma resposta por linha, e deve retornar uma lista de
  temas descritos brevemente, em JSON, identificado somente por uma string. Use o
  tema "Outros" para items que não se encaixem em definições existentes, e
  "Indefinido" se tiver dúvidas sobre como codificar uma certa resposta.
}

header = %{
  Para quem avaliou a feira com nota entre 0 e 8 (até 10), perguntamos: O que a
  organizadora poderia melhorar para você dar nota 10 na sua recomendação?

  Seguem as respostas, uma por linha:
}

batches.each do |batch|
  response = client.chat(
    parameters: {
      model: "gpt-4o-mini",
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: system },
        { role: "user", content: header + "\n\n" + batch.join("\n") }
      ],
      # temperature: 0
    }
  )

  begin
    puts "got: #{response.inspect}"
    puts "-> " + response["choices"].map { |c| c["message"]["content"] }.join("\n") + "\n\n"
  rescue JSON::ParserError => e
    puts "Failed to parse response: #{e}"
    encoded_batch = []
  end

  puts "got: #{encoded_batch.inspect}"
  exit 0
  
  sleep(1) # Respect rate limits.
end
