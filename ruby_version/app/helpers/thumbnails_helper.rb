module ThumbnailsHelper  
  def create_thumbnail(folder, file)
    logger.info "creating thumbnail:: #{folder} / #{file}"
    loc = File.dirname(__FILE__) + "/../assets/images/"+folder+"/"+file
    
    img = Magick::Image.read(loc).first
    img.resize_to_fit!(200, 133)
    
    loc = File.dirname(__FILE__) + "/../assets/images/thumbnails/"+folder+"/"+file
    img.write(loc)   
  end
end
