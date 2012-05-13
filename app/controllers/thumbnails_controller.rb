require 'rubygems'
require 'RMagick'
include Magick

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
  
  
  
end
