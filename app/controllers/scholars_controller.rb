class ScholarsController < ApplicationController
  def index
    @scholars = Scholar.order("COALESCE(citations, 0) desc, name")
    respond_to do |format|
      format.html # template
      format.json { render :json => @scholars }
      format.xml { render :xml => @scholars }
      format.csv { send_data @scholars.to_csv }
      format.xls { send_data @scholars.to_csv(col_sep: "\t") } # tempalte
    end
  end

  def show
    @scholar = Scholar.find(params[:id])
  end

  def new
    @scholar = Scholar.new
  end

  def create
    @scholar = Scholar.new params[:scholar]
    create_or_update
  end

  def edit
    @scholar = Scholar.find(params[:id])
  end

  def update
    @scholar = Scholar.find(params[:id])
    if @scholar.update_attributes(params[:scholar])
      create_or_update
    else
      redirect_to edit_scholar_url, :alert => "Error saving scholar"
    end
  end

  def destroy
    @scholar = Scholar.find(params[:id])
    if @scholar.destroy
      redirect_to scholars_url, :notice => "Scholar deleted successfully"
    else
      redirect_to scholar_url(@scholar), :alert => "Error deleting scholar"
    end
  end

  def update_all
    Scholar.delay.update_all
    redirect_to scholars_url, :notice => "Scholars update all started successfully, check back in a while"
  end

  protected

  def create_or_update
    if @scholar.google_scholar_id.blank? && @scholar.dblp_author_id.blank?
      redirect_to new_scholar_url, :alert => "Both Google Scholar ID and DBLP Author Name are missing"
    elsif @scholar.scrape
      redirect_to scholar_url(@scholar), :notice => "Scholar fetched successfully"
    else
      redirect_to new_scholar_url, :alert => "Error finding scholar"
    end
  end
end
