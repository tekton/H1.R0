class Search < ActiveRecord::Base
  attr_accessible :md5hash, :serial, :new_tag, :new_value
  serialize :serial
end
