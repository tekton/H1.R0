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
    
    @hash_filter = params[:hash_filter]
    
    s = Search.where("md5hash = ?", @hash_filter).first
    
    @tags = YAML::load(s.serial)
    @t = YAML::dump(@tags)
    
    #logger.info @tags
    #logger.info @t
    
    @tags = @tags.to_a
    logger.info "tags.to_a ::: "
    logger.info @tags
    
    @tagz = Array.new
    @values = Array.new
    
    @tags.each do |k,v|
      #logger.info k + " :: " + v
      
      if k == "tag"
        @tagz.push(v)
      end
      
      if k == "value"
        @values.push v
      end
      
    end
    
    ##array for the id's for searching later
    @id_array = Array.new
    
    @exif = ExifDatum.where("tag = ? and value = ?", @tagz, @values).joins(:image).includes(:image)
    @exif.each do |img|
      #logger.info img.image_id
      #logger.info img.image.location
      @id_array.push img.image_id
    end
    
    @exi2 = ExifDatum.select("tag, value, count(*) as count").where("image_id IN (?)", @id_array).group("tag, value").order("tag asc")
    #@exi2 = ExifDatum.all(:conditions => {["image_id = ?", @id_array]}) #.select("tag, value, count(*) as count") ##.group("tag, value").order("tag asc")
      @exi2.each do |exi2_data|
        #logger.info exi2_data.tag + " :: " + exi2_data.value + " :: "+ exi2_data.count
        
        @yml = YAML::dump(s.serial)
        
=begin
@hash_array = Array.new

@yml.each do |t,v|
  logger.info t
  logger.info v
  #@hash_array.push({"tag" => t.tag, "value" => t.value})
end

@hash_array.push({ "tag" => exi2_data.tag, "value" => exi2_data.value })
=end
        
        @yml += "\n---\n\ttag: #{exi2_data.tag}\n\tvalue: #{exi2_data.value}"
        logger.info @yml
        
        logger.info "\n\n"
        #logger.info @hash_array
      end
    
  end
  
end
