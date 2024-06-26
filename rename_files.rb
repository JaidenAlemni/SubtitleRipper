require 'json'
require 'fileutils'

TARGET_DIR = Dir.pwd + "/rename/"
MAP_FILE = "EpisodeMap.json"
EPISODE_MAP = JSON.load(File.open(MAP_FILE))

begin
  series = ARGV[ARGV.index("-series")+1].upcase
  mode = ARGV[ARGV.index("-mode")+1].to_i
  language = ARGV[ARGV.index("-lang")+1].upcase
rescue
  puts "Error loading args"
end
raise "series format incorrect. args: #{ARGV}" unless series
raise "mode format incorrect. args: #{ARGV}" unless mode
raise "language format incorrect. args: #{ARGV}" unless language

# Load files
files = Dir.glob("#{TARGET_DIR}*")
hash = EPISODE_MAP["Series"][series]["Language"][language]

case mode
when 0 # IDs to Friendly
  files.each do |file|
    ext = File.extname(file)
    base = File.basename(file).chomp(ext)
    new_base = hash[base]
    if new_base.nil?
      puts "Skipping ID->ID convert / Mismatched language or series"
      next
    end
    new_name = File.join(File.dirname(file), new_base + ext)
    FileUtils.mv(file, new_name)
  end
when 1 # Friendly to IDs
  files.each do |file|
    ext = File.extname(file)
    base = File.basename(file).chomp(ext)
    new_base = hash.key(base)
    if new_base.nil?
      puts "Skipping Friendly->Friendly convert / Mismatched language or series"
      next
    end
    new_name = File.join(File.dirname(file), new_base + ext)
    FileUtils.mv(file, new_name)
  end
end

