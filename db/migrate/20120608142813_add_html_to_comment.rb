class AddHtmlToComment < ActiveRecord::Migration
  def change
    add_column :comments, :html, :text
  end
end
