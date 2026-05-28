class AddGinIndexToContactsAdditionalAttributes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :contacts, :additional_attributes, using: :gin,
                                                 name: 'index_contacts_on_additional_attributes_gin',
                                                 algorithm: :concurrently
  end
end
