# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/enumerable'
require 'optparse'
require 'http'
require 'csv'
require 'pry'

# options parser
options = {}
OptionParser.new do |opt|
  opt.on('--season SEASON') { |o| options[:season] = o }
  opt.on('--year YEAR') { |o| options[:year] = o }
end.parse!
if %w[WINTER SPRING SUMMER FALL].exclude?(options[:season])
  warn 'Error: Invalid season option, please input the season argument between WINTER, SPRING, SUMMER, or FALL'
  exit(false)
end
unless options[:year].is_a?(Integer) || Integer(options[:year], 10, exception: false)
  warn 'Error: Invalid year option, please input correct year'
  exit(false)
end

puts 'Please wait generating csv.. ⏳'

# params for Anilist.net graphql API
url = 'https://graphql.anilist.co'
query = <<-TEXT
  query (\n\t$season: MediaSeason,\n\t$year: Int,\n\t$format: MediaFormat,\n\t$excludeFormat: MediaFormat,\n\t$status: MediaStatus,\n\t$minEpisodes: Int,\n\t$page: Int,\n){\n\tPage(page: $page) {\n\t\tpageInfo {\n\t\t\thasNextPage\n\t\t\ttotal\n\t\t}\n\t\tmedia(\n\t\t\tseason: $season\n\t\t\tseasonYear: $year\n\t\t\tformat: $format,\n\t\t\tformat_not: $excludeFormat,\n\t\t\tstatus: $status,\n\t\t\tepisodes_greater: $minEpisodes,\n\t\t\tisAdult: false,\n\t\t\ttype: ANIME,\n\t\t\tsort: TITLE_ROMAJI,\n\t\t) {\n\t\t\t\nid\nidMal\ntitle {\n\tromaji\n\tnative\n\tenglish\n}\nstartDate {\n\tyear\n\tmonth\n\tday\n}\nendDate {\n\tyear\n\tmonth\n\tday\n}\nstatus\nseason\nformat\ngenres\nsynonyms\nduration\npopularity\nepisodes\nsource(version: 2)\ncountryOfOrigin\nhashtag\naverageScore\nsiteUrl\ndescription\nbannerImage\nisAdult\ncoverImage {\n\textraLarge\n\tcolor\n}\ntrailer {\n\tid\n\tsite\n\tthumbnail\n}\nexternalLinks {\n\tsite\n\turl\n}\nrankings {\n\trank\n\ttype\n\tseason\n\tallTime\n}\nstudios(isMain: true) {\n\tnodes {\n\t\tid\n\t\tname\n\t\tsiteUrl\n\t}\n}\nrelations {\n\tedges {\n\t\trelationType(version: 2)\n\t\tnode {\n\t\t\tid\n\t\t\ttitle {\n\t\t\t\tromaji\n\t\t\t\tnative\n\t\t\t\tenglish\n\t\t\t}\n\t\t\tsiteUrl\n\t\t}\n\t}\n}\n\nairingSchedule(\n\tnotYetAired: true\n\tperPage: 2\n) {\n\tnodes {\n\t\tepisode\n\t\tairingAt\n\t}\n}\n\n\t\t}\n\t}\n}
TEXT
variables = {
  season: options[:season],
  year: options[:year].to_i,
  format: 'TV',
  page: 1
}
# body = { query: query, variables: variables }

# get anime list data from Anilist.net graphql API
media_list = []
has_nex_page = true
while has_nex_page
  response = HTTP.headers('Content-Type' => 'application/json', 'Accept' => 'application/json')
                 .post(url, json: { query: query, variables: variables })
  if (200..201).exclude?(response.status)
    data = ActiveSupport::JSON.decode(response.to_s)
    warn JSON.pretty_generate(data)
    exit(false)
  end

  data = ActiveSupport::JSON.decode(response.to_s)['data']
  media_list += data.dig('Page', 'media') || []

  has_nex_page = data.dig('Page', 'pageInfo', 'hasNextPage')
  variables[:page] += 1
end

# parse anime list data to csv
csv_result = CSV.generate do |csv|
  csv << %w[cover_image romaji_title english_title format episodes season studios source genres start_date_parsed end_date_parsed] # headers

  media_list.each do |item|
    cover_image = "=IMAGE(\"#{item.dig('coverImage', 'extraLarge')}\"; 1)"
    romaji_title = item.dig('title', 'romaji')
    english_title = item.dig('title', 'english')

    format = item['format']
    episodes = item['episodes']
    season = item['season']
    studios = (item.dig('studios', 'nodes') || []).pluck('name').join(', ')
    source = item['source']
    genres = (item['genres'] || []).join(', ')

    start_date = if item['startDate'].values.any?(nil)
                   (item.dig('startDate',
                             'year') || nil)
                 else
                   item['startDate']
                 end
    end_date = if item['endDate'].values.any?(nil)
                 (item.dig('endDate',
                           'year') || nil)
               else
                 item['endDate']
               end
    start_date_parsed = if start_date.is_a?(Hash)
                          Time.gm(start_date['year'], start_date['month'],
                                  start_date['day'])&.to_date&.to_formatted_s(:rfc822)
                        else
                          start_date
                        end
    end_date_parsed = if end_date.is_a?(Hash)
                        Time.gm(end_date['year'], end_date['month'],
                                end_date['day'])&.to_date&.to_formatted_s(:rfc822)
                      else
                        end_date
                      end

    csv << [
      cover_image,
      romaji_title,
      english_title,
      format,
      episodes,
      season,
      studios,
      source,
      genres,
      start_date_parsed,
      end_date_parsed
    ]
  end
end

# save csv file
# file_season = media_list.dig(0, "season")
# file_year = media_list.dig(0, "startDate", "year")
path = File.join(__dir__, "anime_list_#{options[:year]}_#{options[:season]}.csv")
File.write(path, csv_result.to_s)
puts 'Done ✅'

# exit program
exit(true)
