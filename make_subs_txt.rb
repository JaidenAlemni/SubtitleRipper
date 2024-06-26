require 'csv'

def form_line(hash)
  jp_line = [hash["role"], hash["content"]].join(": ")
  en_line = [hash["role_en"], hash["content_en"]].join(": ")
  line = jp_line + "\n" + en_line
  line
end

# Load CSV
filename = ARGV[0]
unless filename
  puts "Please provide a CSV file!"
  exit
end
file = Dir.pwd + "/subs/#{filename}"
if !File.exist?(file)
    puts "No CSV file found! Aborting."
    exit
end

puts "Converting CSV to TXT..."
subs_out = []
CSV.foreach(file, headers: true) do |row|
  line = form_line(row.to_h)
  subs_out << line
end
# Save to file

path = Dir.pwd + "/#{filename.chomp(".csv")}.txt"
srt_string = subs_out.join("\n\n\n")
File.write(path, srt_string)
puts "Done! (⁠⁠´⁠ω⁠｀⁠⁠)"


