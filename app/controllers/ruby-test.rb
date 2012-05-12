require 'rubygems'
require 'exifr'
require 'logger'

def find_files(loc)
	files = Dir.new(loc)
	Dir.chdir(loc)
	files.each do |file|
		case file.downcase
		when /.jpg\Z/
			$log.debug "#{file} is a jpg!"
			exif_data = nil
			exif_data = EXIFR::JPEG.new(file)
			exif_loop(exif_data)
		end
	end
end

def exif_loop(exif_data)
	if exif_data.exif? then
		i = exif_data.exif.to_hash
		i.each_pair do |key,val|
			#puts "#{key} :: #{val}"
			#h[key]
			if $h.has_key?(key)
				$log.debug "#{key} exists!"
				if $h[key].has_key?(val)
					$h[key][val] += 1
				else
					$h[key][val] = 1
				end
			else
				$log.debug "Key didn't exit, making new hash of hash"
				$h[key] = Hash.new()
				$h[key][val] = 1
			end
		end
	else
		puts "NO DATA"
	end
end

def i_h(h)
	h.each_key do |k|
		puts "#{k} ::"
			h[k].each_pair do |key,val|
				puts "     #{key} :: #{val}"
			end
	end
end

t = Time.now()
$h = Hash.new()
$log = Logger.new('log')
loc = ARGV.first
find_files(loc)

$log.debug $h.inspect

i_h($h)

t = Time.now() - t
puts t
