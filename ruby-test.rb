require 'rubygems'
require 'exifr'

def find_files(loc)
	files = Dir.new(loc)
	files.each do |file|
		case file.downcase
		when /.jpg\Z/
			puts "A jpg!"
		end
	end
end

img_file = ARGV.first
exif_data = nil
exif_data = EXIFR::JPEG.new(img_file)
h = Hash.new()

if exif_data.exif? then
	i = exif_data.exif.to_hash
	i.each_pair do |key,val|
		#puts "#{key} :: #{val}"
		#h[key]
		if h.has_key?(key)
			puts "#{key} exists!"
			if h[key].has_key?(val)
				h[key][val] += 1
			else
				h[key][val] = 1
			end
		else
			puts "Key didn't exit, making new hash of hash"
			h[key] = Hash.new()
			h[key][val] = 1
		end
	end
else
	puts "NO DATA"
end

puts h.inspect
