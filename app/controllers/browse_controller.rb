class BrowseController < ApplicationController
  # GET /
  def index
    @images = Image.order(:name).order("RANDOM()").limit(4) ### TODO: needs to be optimized, because this gets out of hand quickly...
    
    ### Get exif tags list w/count
    
    #@exif = ExifDatum.calculate(:count, :value, :group => "tag", :select => :tag)
    @exif = ExifDatum.select("tag, value, count(*) as count").group("tag, value").order("tag asc")
    logger.info "######################"
    #logger.info @exif
    @exif.each do |exif_data|
      logger.info exif_data.tag + " :: " + exif_data.value + " :: " + exif_data.count.to_s
    end
    logger.info "######################"
  end
end
