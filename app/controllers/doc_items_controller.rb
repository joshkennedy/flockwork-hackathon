class DocItemsController < ApplicationController
  before_action :set_project
  before_action :set_doc_item, only: %i[ show edit update destroy download ]
  before_action :authorize_manage_docs, except: :download
  before_action :authorize_update_doc_item, only: %i[ edit update ]
  before_action :authorize_download, only: %i[ show download ]
  before_action :authorize_destroy_doc_item, only: :destroy
  before_action :require_uploaded_file, only: %i[ create update ]

  def new
    @doc_item = @project.doc_items.build(kind: doc_item_kind_param)
  end

  def create
    @doc_item = @project.doc_items.build(doc_item_params)
    @doc_item.author = Current.person

    if @doc_item.save
      redirect_to @project
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    raise ActiveRecord::RecordNotFound unless @doc_item.file?

    @viewer_kind = viewer_kind
  end

  def edit
  end

  def update
    if @doc_item.update(doc_item_params)
      redirect_to @project
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @doc_item.destroy!
    redirect_to @project
  end

  def download
    data = @doc_item.file.download
    sniffed_type = Marcel::MimeType.for(StringIO.new(data))
    send_data data,
      filename: @doc_item.file.filename.to_s,
      type: ActiveStorage.content_types_allowed_inline.include?(sniffed_type) ? sniffed_type : ActiveStorage.binary_content_type,
      disposition: "attachment"
  end

  private
    # Decided from the claimed type only to choose a viewer; bytes still come from #download, which sniffs.
    def viewer_kind
      content_type = @doc_item.file.content_type
      if content_type == "application/pdf"
        :pdf
      elsif content_type.start_with?("image/") && ActiveStorage.content_types_allowed_inline.include?(content_type)
        :image
      end
    end

    def set_project
      @project = Policy.visible_projects(Current.person).find(params[:project_id])
    end

    def set_doc_item
      @doc_item = @project.doc_items.find(params[:id])
    end

    def authorize_manage_docs
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :manage_docs, @project)
    end

    def authorize_download
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :download, @doc_item)
    end

    def authorize_destroy_doc_item
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :destroy, @doc_item)
    end

    def authorize_update_doc_item
      raise ActiveRecord::RecordNotFound unless Policy.can?(Current.person, :update, @doc_item)
    end

    def require_uploaded_file
      file = params.dig(:doc_item, :file)
      head :unprocessable_content if file.present? && !file.is_a?(ActionDispatch::Http::UploadedFile)
    end

    def doc_item_kind_param
      kind = params[:kind].to_s
      return kind if DocItem.kinds.key?(kind)

      "document"
    end

    def doc_item_params
      permitted = [ :kind, :title, :url, :body, :file ]
      params.expect(doc_item: permitted)
    end
end
