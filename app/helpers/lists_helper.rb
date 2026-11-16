module ListsHelper
  def list_row_label(list, row)
    list.columns.lazy.filter_map do |column|
      column.display(row.cells[column.id.to_s]).presence
    end.first
  end
end
