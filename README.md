# aisrt

Quick script to translate subtitles in srt to different languages.

Work in progress!

## Usage:

```
cp .env.sample .env
# fill with your OpenAI key
bundle install
bundle exec ruby ./lib/aisrt.rb --srt ./some-subtitle.srt --from pt-br --to en
```
