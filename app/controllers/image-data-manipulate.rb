require 'rubygems'
require 'mini_exiftool'
require 'exifr'
require 'logger'

class ImageDataManipulate

  log = Logger.new('idm-log.log')
  loc = ""
  
  def copy_image(img)
  	#name of file
  	name = File.basename(img)
  	new_img = "~/tmp/"+name
  	#open the file location provided by the variable img
  	if File.exist?(img)
  		#copy the file to ~/tmp for testing
  		FileUtils.cp(img, File.expand_path("~/tmp"))
  		#add original location as exif data
  		photo = MiniExiftool.new(File.expand_path(new_img))
  		photo["UserComment"] = img
  		photo.save
  		#assuming that worked, return
  		return true
  	else
  		return false
  	end
  
  end
end
