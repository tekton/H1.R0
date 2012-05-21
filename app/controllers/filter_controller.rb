class FilterController < ApplicationController
  
  def filter
    
    @filter = params[:filter]
    @val = params[:val]
      #due to using very simple routes and not wanting to override things, we'll just undo changes!
      @val = @val.gsub("__","/")
    @format = params[:format]
    
    #more do un-d-ing
    if @format != nil
      @val += "."+@format
    end
    
    @exif = ExifDatum.where("tag = ? AND value = ?", @filter, @val).joins(:image).includes(:image)
      @exif.each do |exif_datum|
        logger.info exif_datum.image_id
        logger.info exif_datum.image.location
      end
    #@exi2 = ExifDatum.select("tag, value, count(*) as count").where("tag = ? AND value = ?", @filter, @val).group("tag, value").order("tag asc")
    
  end
  
end
