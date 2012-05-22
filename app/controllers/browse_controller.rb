class BrowseController < ApplicationController
  
  # GET /
  def index
    @images = Image.order(:name).order("RANDOM()").limit(4) ### TODO: needs to be optimized, because this gets out of hand quickly...
    
    @base = Digest::MD5.new.update("")
    logger.info @base
    
    ### Get exif tags list w/count
    
    #@exif = ExifDatum.calculate(:count, :value, :group => "tag", :select => :tag)
    @exif = ExifDatum.select("tag, value, count(*) as count").group("tag, value").order("tag asc")
    logger.info "######################"
    #logger.info @exif
    @exif.each do |exif_data|
      logger.info exif_data.tag + " :: " + exif_data.value + " :: " + exif_data.count.to_s
      @h = { "tag" => exif_data.tag, "value" => exif_data.value }
      @y = @h.to_yaml
      @q = Digest::MD5.new.update(@y)
      
      ### TODO: create helper for this and "start" from a blank hash...
      filter_check(@q.to_s, @y)
      
      exif_data.q = @q
    end
    logger.info "######################"
  end
end
