require 'rubygems'
require 'mini_exiftool'
require 'exifr'
require 'logger'

def copy_image(img)
	#name of file
	name = File.basename(img)
	#open the file location provided by the variable img
	if File.exist?(img)
		#copy the file to ~/tmp for testing
		#File.open("~/tmp/"+name,  "w+") {|f| f.write()}
		#FileUtils.cp(img, "~/tmp/"+name)		
		#add original location as exif data
		#photo = MiniExiftool.new("~/tmp/"+name)
		photo = MiniExiftool.new(img)
		photo["UserComment"] = img
		photo.save
		#assuming that worked, return
		return true
	else
		return false
	end

end

$log = Logger.new('idm-log.log')
loc = ARGV.first
copy_image(loc)
