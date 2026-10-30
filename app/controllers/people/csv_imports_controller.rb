module People
  class CsvImportsController < ApplicationController
    include WorkspaceAccess
    include AdminOnly

    def new
    end

    def create
      file = params.require(:csv_file)
      @result = CsvImport.new(Current.workspace, file.read).call

      if @result.fatal_error
        flash.now[:alert] = @result.fatal_error
        render :new, status: :unprocessable_entity
      else
        render :create
      end
    end
  end
end
