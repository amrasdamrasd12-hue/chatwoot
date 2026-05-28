class Account::ContactsExportJob < ApplicationJob
  queue_as :low

  def perform(account_id, user_id, column_names, params)
    @account = Account.find(account_id)
    @params = params
    @account_user = @account.users.find(user_id)

    export = Contacts::ExportBuilder.new(account: @account, user: @account_user, column_names: column_names, params: @params)
    attach_export_file(export.generate)
    send_mail
  end

  private

  def attach_export_file(workbook_data)
    return if workbook_data.blank?

    @account.contacts_export.attach(
      io: StringIO.new(workbook_data),
      filename: "#{@account.name}_#{@account.id}_contacts.xlsx",
      content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    )
  end

  def send_mail
    file_url = account_contact_export_url
    mailer = AdministratorNotifications::AccountNotificationMailer.with(account: @account)
    mailer.contact_export_complete(file_url, @account_user.email)&.deliver_later
  end

  def account_contact_export_url
    Rails.application.routes.url_helpers.rails_blob_url(@account.contacts_export)
  end
end
