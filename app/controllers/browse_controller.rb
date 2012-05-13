class BrowseController < ApplicationController
  # GET /
  def index
    @images = Image.order(:name).limit(4)
    
    ### Get exif tags list w/count
    
    @exif = ExifDatum.calculate(:count, :value, :group => "tag", :select => :tag)
    logger.info "######################"
    logger.info @exif
    logger.info "######################"
  end
end
