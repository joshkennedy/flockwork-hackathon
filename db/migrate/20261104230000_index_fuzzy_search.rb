class IndexFuzzySearch < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    enable_extension "pg_trgm"
    { projects: :name, people: :name, tasks: :title, slots: :label, schedule_items: :title, doc_items: :title }.each do |table, column|
      add_index table, column, using: :gin, opclass: :gin_trgm_ops, name: "index_#{table}_search", algorithm: :concurrently
    end
  end
end
