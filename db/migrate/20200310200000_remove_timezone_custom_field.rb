# frozen_string_literal: true

class RemoveTimezoneCustomField < ActiveRecord::Migration[5.2]
  def change
    UserCustomField.where(name: 'timezone').delete_all
  end
end
