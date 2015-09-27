require 'rubygems'
require 'exifr'

class EXIFGatherFile
  
  def initialize
    @h = Hash.new()
  end
  
  def find_file(loc)
  	case loc.downcase
  	when /.jpg\Z/
  		exif_data = nil
  		exif_data = EXIFR::JPEG.new(loc)
  		exif_loop(exif_data)
  	end
  	
  	return @h
  end
  
  def find_files(loc)
    files = Dir.new(loc)
    Dir.chdir(loc)
    files.each do |file|
      case file.downcase
      when /.jpg\Z/
        logger.info "#{file} is a jpg!"
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
  			if @h.has_key?(key)
  				if @h[key].has_key?(val)
  					@h[key][val] += 1
  				else
  					@h[key][val] = 1
  				end
  			else
  				@h[key] = Hash.new()
  				@h[key][val] = 1
  			end
  		end
  	else
  		puts "NO DATA"
  	end
  end
end
