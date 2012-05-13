class BrowseController < ApplicationController
  def index
    @images = Image.order(:name)
  end
end
