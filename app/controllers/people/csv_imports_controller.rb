module People
  class CsvImportsController < ApplicationController
    include AdminOnly

    def new
    end

    def create
      file = params.require(:csv_file)
      if file.size > CsvImport::MAX_BYTES
        flash.now[:alert] = CsvImport::TOO_LARGE_MESSAGE
        render :new, status: :unprocessable_entity
        return
      end

      @result = CsvImport.new(Current.organization, file.read).call

      if @result.fatal_error
        flash.now[:alert] = @result.fatal_error
        render :new, status: :unprocessable_entity
      else
        render :create
      end
    end
  end
end
