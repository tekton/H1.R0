class ApplicationController < ActionController::Base
  protect_from_forgery
  
  
  def filter_check_old(left, tag, val, y)
    ### check the search table for the hash and for the tag, val...if they're not there, make them!
    logger.info left
    logger.info tag
    logger.info val
    logger.info y
    ## add the new tag/val to the existing yaml...
    
    #search = Search.where("left = ? AND new_tag = ? AND new_value = ? ",left, tag, val).first_or_create!(:md5hash => q, :serial => y)
    
  end

  def filter_check(md5hash, y)
    ### check the search table for the hash and for the tag, val...if they're not there, make them!
    logger.info md5hash
    logger.info y
    ## add the new tag/val to the existing yaml...
    
    search = Search.where("md5hash = ?", md5hash).first_or_create!(:serial => y)
    
  end
  
end
