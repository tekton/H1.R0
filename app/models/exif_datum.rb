class ExifDatum < ActiveRecord::Base
  attr_accessible :parent, :tag, :value
  validates :parent, :presence => true
end
