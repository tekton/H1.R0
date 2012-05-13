require 'rubygems'
require 'RMagick'

class IptcParseController < ApplicationController
  def iptc_from_folder
    folder = params[:test]
    loc = File.dirname(__FILE__) + "/../assets/images/"+folder
    files = Dir.new(loc)
    
    Dir.chdir(loc)
    files.each do |file|
      case file.downcase
      when /.jpg\Z/
        logger.info "Calling get_iptc with #{folder} :: #{file}"
        get_iptc folder, file
      end
    end
    
  end
  
  def get_iptc(folder, file)  
    logger.info "get_iptc:: #{folder} / #{file}"
    loc = File.dirname(__FILE__) + "/../assets/images/"+folder+"/"+file
    
    img = Magick::Image.read(loc).first
    img.each_iptc_dataset do |k,v|
      logger.info "#{k} :: #{v}"
    end
    
    loc = File.dirname(__FILE__) + "/../assets/images/thumbnails/"+folder+"/"+file
    #img.write(loc)   
  end
end
