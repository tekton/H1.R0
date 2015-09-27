require 'rubygems'
require 'RMagick'

class ThumbnailsController < ApplicationController
  
  # GET /thumbnail/:test
  def create
    #folder = :test.to_s
    folder = "test"
    image = params[:test]+".jpg"
    
    logger.info "#{folder} :: #{image}"
    loc = File.dirname(__FILE__) + "/../assets/images/"+folder+"/"+image
    logger.info "#{loc}"
    
    img = Magick::Image.read(loc).first
    img.resize_to_fit!(200, 133)
    
    loc = File.dirname(__FILE__) + "/../assets/images/thumbnails/"+image
    img.write(loc)
  end
  
  def create_from_folder
    folder = params[:test]
    loc = File.dirname(__FILE__) + "/../assets/images/"+folder
    files = Dir.new(loc)
    
    Dir.chdir(loc)
    files.each do |file|
      case file.downcase
      when /.jpg\Z/
        logger.info "Calling create_thumbnail with #{folder} :: #{file}"
        #create_thumbnail folder, file
        ThumbnailsWorker.perform_async(folder, file)
      end
    end
    
  end
  
  def create_thumbnail(folder, file)
    logger.info "creating thumbnail:: #{folder} / #{file}"
    loc = File.dirname(__FILE__) + "/../assets/images/"+folder+"/"+file
    
    img = Magick::Image.read(loc).first
    img.resize_to_fit!(200, 133)
    
    loc = File.dirname(__FILE__) + "/../assets/images/thumbnails/"+folder+"/"+file
    img.write(loc)   
  end
  
end
