# ===========================================================================
# * Subtitle Downloader and Converter
# ---------------------------------------------------------------------------
# This is a very primative script I created for downloading and converting
# subtitle files from a certain website and converting them to various formats. 
# 
# The URLs/website titles have been redacted for privacy reasons.
#
# [How To Use]
#
# Install Ruby
#
# In a command line, use this format (unix may require quotes around url)
#   ruby subdl.rb https://url.com/id=xxx
#   ruby subdl.rb https://url.com/id=xxx -f
#
# If you'd like, you may also just enter the ID:
#   ruby subdl.rb XXXXXXX 
#   ruby subdl.rb XXXXXXX -f
#
# The -f flag will apply color and font formatting to SRT files. Note that
# this may not be supported with all subtitles.
#
# It will check the folder for a file with the matching URL id before
# downloading again when using the conversion functions.
#
# This script also allows converting CSV from JSON, and then converting
# those CSV files into SRTs. This allows for editing the "content" of each
# subtitle in a spreadsheet, then converting into usable subtitles later.
# Please note that the order must be exactly the same and there can only be
# one "content" column. The header row will be dropped upon conversion.
#
# This doesn't check for file overwriting, so make sure you make a copy of 
# your own work before downloading new JSONs / converting new CSVs/SRTs!
# ===========================================================================
require 'net/http'
require 'cgi'
require 'json'
require 'csv'
require 'fileutils'
# For XML
require 'nokogiri'
require 'open-uri'
# Gem dependency
require 'down'

class SubDownloader
  attr_accessor :sound_id
  attr_accessor :sub_url
  attr_accessor :format_srt
  attr_accessor :use_xml
  attr_reader   :info_url

  def initialize(sound_id = nil)
    if sound_id
      @sound_id = sound_id
    end
  end

  def info_url
    "[[URL GOES HERE]]=#{@sound_id}"
  end

  def format_srt?
    @format_srt
  end

  # Get JSON body from url
  def json_body_from_url(url)
    uri = URI.parse(url)
    res = Net::HTTP.get_response(uri)
    json = JSON.load(res.body)
    json
  end

  # def auth_request(url)
  #   uri = URI.parse(url)
  #   http = Net::HTTP.new(uri.host, uri.port)
  #   request = Net::HTTP::Get.new(uri.request_uri)
  #   token = "[[TOKEN]]"
  #   request['Cookie'] = "token=#{token}"
  #   res = http.request(request)
  #   res
  # end

  # Converts url query to usable hash
  def query_to_hash(query)
    qh = {}
    qary = query.split("&")
    qary.each do |item|
      key, value = item.split("=")
      qh[key] = value
    end
    qh
  end

  def fetch_audio_url
    json_body = json_body_from_url(self.info_url)
    # begin
    #   json_body = json_body_from_url(self.info_url)
    # rescue Exception e
    #   puts "Failed to fetch info!"
    #   exit
    # end
    puts json_body
    sound_url = json_body["info"]["sound"]["soundurl"]
    if sound_url
      puts sound_url
    else
      puts "No sound URL found （；´д｀）" 
    end
    sound_url
  end

  def fetch_image_url
    begin
      json_body = json_body_from_url(self.info_url)
    rescue
      puts "Failed to fetch info!"
      exit
    end
    sound_url = json_body["info"]["sound"]["front_cover"]
    puts "No image URL found （；´д｀）" unless sound_url
    sound_url
  end

  def save_file(url)
   

    puts "Downloading file..."

    tempfile = Down.download(url)

    puts "Downloaded. Copying to folder..."
    # Copy & rename the tempfile
    path = File.join(Dir.pwd, "dl", tempfile.original_filename)
    FileUtils.mv(tempfile, path)

    puts "Done!"
  end

  # The formats here were specific to the website I was downloading from at the time.
  def download_xml_subs(save_format = nil)
    puts "Getting subs from [[site]]..."
    self.sub_url = "[[URL]]=#{@sound_id}"
    #uri = URI.parse(@sub_url)
    opts = Nokogiri::XML::ParseOptions.new.huge
    #doc = Nokogiri::XML::Document.parse(File.open(Dir.pwd + "/2020.xml"), nil, nil, opts)
    doc = Nokogiri::XML::Document.parse(URI.open(@sub_url), nil, nil, opts)
    # Get comment array
    comments = doc.xpath("//d")
    sub_data = []
    last_time = 0.0
    comments.reverse.each do |comment|
      # Position data looks something like this 
      # "1801,  4,  25, 6333933,  1580365918, 240,  26, 8967"
      # time, mode, size, color, date, pool, hash, dbid
      seconds, _mode, _size, color, _date, pool, _hash, _dbid = comment['p'].split(",")
      # It seems main subs are consistently 240
      next unless pool == "240"
      text = comment.content.split(":")
      if text.size > 1
        role = text.shift
        content = text.join
      else
        role = ""
        content = text[0]
      end
      # Calc start / end times and color
      end_time = secs_to_ms(seconds.to_f)
      start_time = secs_to_ms(last_time)
      last_time = seconds.to_f - 0.5
      sub_data << {
        start_time: start_time,
        end_time: end_time,
        role: role,
        content: content,
        color: color_to_hex(color.to_i),
        italic: false,
        underline: false
      }
    end
    case save_format
    when :json
      puts "Writing raw JSON to file."
      path = Dir.pwd + "/subs/#{self.sound_id}.json"
      begin
        File.open(path, 'w') do |file|
          JSON.dump(sub_data, file)
        end
      rescue
        puts "Failed to dump JSON."
      else
        puts "Done! (⁠⁠´⁠ω⁠｀⁠⁠)"
      end
    when :csv
      json_to_csv(sub_data)
    when :srt
      json_to_srt(sub_data)
    else
      return sub_data
    end
  end

  # To file saves to a file, otherwise returns the json object instead
  def download_json(to_file = false)
    puts "Getting subtitle URL..."

    # Get from info URL
    begin
      info_json = json_body_from_url(self.info_url)
    rescue
      puts "Failed to get info URL! Exiting."
      exit
    end
    
    self.sub_url = info_json["info"]["sound"]["subtitle_url"]
  
    puts "Got subtitle URL!: #{@sub_url} \nFetching subtitles..."
    
    begin
      sub_json = json_body_from_url(@sub_url)
    rescue
      #puts "Failed to get subtitles! Exiting."
      #exit
      puts "Failed to get subtitles!"
      return nil
    end
    
    puts "Got subtitles!"
    
    if to_file
      puts "Writing raw JSON to file."
      
      path = Dir.pwd + "/subs/#{self.sound_id}.json"
      
      begin
        File.open(path, 'w') do |file|
          JSON.dump(sub_json, file)
        end
      rescue
        puts "Failed to dump JSON."
      else
        puts "Done! (⁠⁠´⁠ω⁠｀⁠⁠)"
      end
    else
      # Return response
      return sub_json
    end
  end

  def check_json_file
    file = Dir.pwd + "/subs/#{@sound_id}.json"
    if File.exist?(file)
      puts "Found existing file #{@sound_id}!"
      json_obj = JSON.load_file(file)
    else
      json_obj = download_json
    end
    json_obj
  end

  # Credit: sarah/coffeecryptid
  def json_to_srt(json = nil)
    subs_out = []
    # Check for json file existence first
    json = check_json_file unless json
    return if json.nil?
    puts "Converting to SRT..."
    # Go line for line
    json.each_with_index do |hash, index|
      entry = subtitle_entry(index+1, hash)
      subs_out << entry
    end
    # Save to file
    path = Dir.pwd + "/subs/#{@sound_id}.srt"
    srt_string = subs_out.join("\n\n\n")
    File.write(path, srt_string)
    puts "Done! (⁠⁠´⁠ω⁠｀⁠⁠)"
  end

  def json_to_csv(json = nil)
    # Check for json file existence first
    json = check_json_file unless json
    if json.nil?
      puts "Skipping"
      return
    end
    puts "Attempting to convert JSON to CSV..."
    csv_string = CSV.generate do |csv|
      # Header row
      csv << json[0].keys
      json.each do |hash|
        csv << hash.values
      end
    end
    path = Dir.pwd + "/subs/#{@sound_id}.csv"
    File.write(path, csv_string)
    puts "Done! (⁠⁠´⁠ω⁠｀⁠⁠)"
  end

  def csv_to_srt
    file = Dir.pwd + "/subs/#{@sound_id}.csv"
    if !File.exist?(file)
      puts "No CSV file for #{@sound_id} found! Aborting"
      exit
    end
    puts "Converting CSV to SRT..."
    subs_out = []
    index = 1
    CSV.foreach(file, headers: true) do |row|
      hash = row.to_h
      entry = subtitle_entry(index, hash)
      subs_out << entry
      index += 1
    end
    # Save to file
    path = Dir.pwd + "/subs/#{@sound_id}.srt"
    srt_string = subs_out.join("\n\n\n")
    File.write(path, srt_string)
    puts "Done! (⁠⁠´⁠ω⁠｀⁠⁠)"
  end

  def color_to_hex(num)
    hex = "#" + num.to_i.to_s(16)
    hex
  end

  def secs_to_ms(seconds_f)
    return Integer(seconds_f * 1000)
  end

  # Convert MS to srt timestamp
  # 00:00:00,000 
  def format_time(value)
    # case type
    # when :seconds
    #   # I'm sure there's a better way to do this
    #   rsecs = value.floor
    #   if rsecs > 0
    #     remainder = (value.divmod(rsecs)[1].round(2) * 1000).round
    #   else
    #     remainder = 0
    #   end
    #   sec = Time.at(rsecs).utc
    #   r_string = '%03d' % remainder
    #   return sec.strftime("%H:%M:%S") + "," + r_string
    # end
  end

  # Credit: sarah/coffeecryptid
  # Rewrite by jaiden
  def format_text(hash)
    if hash["role"] != ""
      raw_text = [hash["role"], hash["content"]].join(": ")
    else
      raw_text = hash["content"]
    end

    if format_srt?
      formatted_text = raw_text
      if hash["italic"] == true
        formatted_text = "<i>#{formatted_text}</i>"
      end
      if hash["underline"] == true
        formatted_text = "<u>#{formatted_text}</u>"
      end
      if hash["color"]
        color = color_to_hex(hash["color"])
        formatted_text = "<font color=\"#{color}\">#{formatted_text}</font>"
      end
    else
      formatted_text = raw_text
    end

    formatted_text
  end
  
  # srt format:
=begin
  1
  00:02:16,612 --> 00:02:19,376
  Senator, we're making
  our final approach into Coruscant.

  2
  00:02:19,482 --> 00:02:21,609
  Very good, Lieutenant.
=end
  def subtitle_entry(number, hash)
    start_time = format_time(hash["start_time"])
    end_time = format_time(hash["end_time"])
    text = format_text(hash)

    entry = "#{number.to_s}\n#{start_time} --> #{end_time}\n#{text}"
    entry
  end

end



## Program starts here
downloader = SubDownloader.new

if ARGV.include?("-x")
  downloader.use_xml = true
end

if ARGV.include?("-f")
  downloader.format_srt = true
end

# Process batch (undocumented)
if ARGV[0] == "-b"
  # Load list
  file = File.join(Dir.pwd, ARGV[1])
  puts "Processing batch from #{file}"
  name = "[[TITLE]]"
  puts "Using #{name} Sound IDs."
  if File.exist?(file)
    File.readlines(file, "\n").each do |line|
      downloader.sound_id = line.strip.to_i
      if ARGV[2] == "-a"
        case ARGV[3]
        when 'csv_to_srt'
          downloader.csv_to_srt
        when 'json_to_srt'
          downloader.json_to_srt
        when 'json_to_csv'
          downloader.json_to_csv
        when 'audio_files'
          downloader.fetch_audio_url
        when 'image_files'
          downloader.fetch_image_url
        end
      else
        puts "Downloading #{line}"
        if downloader.xml?
          downloader.download_xml(:json)
        else
          downloader.download_json(true)
        end
        # Don't thrash their servers too hard
        sleep(5)
      end
    end
  else
    puts "Couldn't load batch."
  end
  exit
end


# Get ID
id = ARGV[0].scan(/\d+$/)
if id != []
  id = id[0]
  puts "Using #{id} for files / URLs"
  downloader.sound_id = id
# URL
else
  puts "Invalid format in URL/ID! Exiting."
  exit
end


puts "SRTs will be formatted to include color / bold / italics." if downloader.format_srt?
puts "Please choose from one of the options."
puts "------------------------------"
puts "0 : Download and save subtitles in raw JSON"
puts "1 : Convert JSON to SRT (json will be downloaded if not found)"
puts "2 : Convert JSON to CSV (json will be downloaded if not found)"
puts "3 : Convert CSV to SRT"
puts "4 : Download audio file"
puts "5 : Cancel and Exit"
puts "------------------------------"

ARGV.clear

user_choice = nil
while user_choice.nil? do
  user_choice = gets.chomp.to_i
  unless [0,1,2,3,4,5].include?(user_choice)
    puts "Invalid choice! Please try again, or press CTRL+C to exit."
    user_choice = nil
  end
  if user_choice == 5
    exit
  end
end 

case user_choice
when 0
  if downloader.use_xml?
    downloader.download_xml(:json)
  else
    downloader.download_json(true)
  end
when 1
  json = downloader.use_xml? ? downloader.download_xml : nil
  downloader.json_to_srt(json)
when 2
  json = downloader.use_xml? ? downloader.download_xml : nil
  downloader.json_to_csv(json)
when 3
  downloader.csv_to_srt
when 4
  url = downloader.fetch_audio_url
  if url
    downloader.save_file(url)
  end
end

