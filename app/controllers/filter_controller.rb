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
    
    ### Get the data and modle it into various forms...
    
    @id_array = Array.new
    
    @exif = ExifDatum.where("tag = ? AND value = ?", @filter, @val).joins(:image).includes(:image)
      @exif.each do |exif_datum|
        logger.info exif_datum.image_id
        @id_array.push exif_datum.image_id
        logger.info exif_datum.image.location
      end
      
    @exi2 = ExifDatum.select("tag, value, count(*) as count").where("image_id IN (?)", @id_array).group("tag, value").order("tag asc")
    #@exi2 = ExifDatum.all(:conditions => {["image_id = ?", @id_array]}) #.select("tag, value, count(*) as count") ##.group("tag, value").order("tag asc")
      @exi2.each do |exi2_data|
        logger.info exi2_data.tag + " :: " + exi2_data.count
      end
    
  end
  
  def hash_filter
    
    @hash_filter = params[:hash]
    
  end
  
end
