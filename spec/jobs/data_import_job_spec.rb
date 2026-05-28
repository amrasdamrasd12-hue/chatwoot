require 'rails_helper'

RSpec.describe DataImportJob do
  subject(:job) { described_class.perform_later(data_import) }

  let!(:data_import) { create(:data_import) }

  describe 'enqueueing the job' do
    it 'queues the job on the low priority queue' do
      expect { job }.to have_enqueued_job(described_class)
        .with(data_import)
        .on_queue('low')
    end
  end

  describe 'retrying the job' do
    context 'when ActiveStorage::FileNotFoundError is raised' do
      let(:import_file_double) { instance_double(ActiveStorage::Blob) }

      before do
        allow(data_import).to receive(:import_file).and_return(import_file_double)
        allow(import_file_double).to receive(:open).and_raise(ActiveStorage::FileNotFoundError)
      end

      it 'retries the job' do
        expect do
          described_class.perform_now(data_import)
        end.to have_enqueued_job(described_class).at_least(1).times
      end
    end
  end

  describe 'importing data' do
    context 'when the data is valid' do
      it 'imports data into the account' do
        rows = xlsx_rows(data_import.import_file.download)

        described_class.perform_now(data_import)
        expect(data_import.account.contacts.count).to eq(rows.length)
        expect(data_import.reload.total_records).to eq(rows.length)
        expect(data_import.reload.processed_records).to eq(rows.length)
        contact = Contact.find_by(phone_number: '+918080808080')
        expect(contact).to be_truthy
        expect(contact['additional_attributes']['company']).to eq('My Company Name')
      end
    end

    context 'when the data contains errors' do
      it 'imports erroneous data into the account, skipping invalid records' do
        # Last record is invalid because of duplicate email
        invalid_data = [
          %w[id first_name last_name email phone_number],
          ['1', 'Clarice', 'Uzzell', 'cuzzell0@mozilla.org', '+918484848484'],
          ['2', 'Marieann', 'Creegan', 'mcreegan1@cornell.edu', '+918484848485'],
          ['3', 'Nancey', 'Windibank', 'cuzzell0@mozilla.org', '+91848484848']
        ]

        invalid_data_import = create(:data_import, import_file: generate_xlsx_file(invalid_data))
        rows = xlsx_rows(invalid_data_import.import_file.download)

        described_class.perform_now(invalid_data_import)
        expect(invalid_data_import.account.contacts.count).to eq(rows.length - 1)
        expect(invalid_data_import.reload.total_records).to eq(rows.length)
        expect(invalid_data_import.reload.processed_records).to eq(rows.length)
      end

      it 'will preserve emojis' do
        emoji_data = [
          %w[id name email phone_number],
          ['1', 'T 🏠 🔥 Test', 'emoji@example.com', '+918080808088']
        ]
        data_import = create(:data_import, import_file: generate_xlsx_file(emoji_data))
        rows = xlsx_rows(data_import.import_file.download)

        described_class.perform_now(data_import)
        expect(data_import.account.contacts.count).to eq(rows.length)

        expect(data_import.account.contacts.first.name).to eq('T 🏠 🔥 Test')
      end

      it 'will preserve Arabic text' do
        arabic_data = [
          %w[id name email phone_number company],
          ['1', 'أحمد علي', 'ahmed@example.com', '+918080808089', 'شركة الاختبار']
        ]
        arabic_data_import = create(:data_import, import_file: generate_xlsx_file(arabic_data))
        rows = xlsx_rows(arabic_data_import.import_file.download)

        described_class.perform_now(arabic_data_import)
        expect(arabic_data_import.account.contacts.count).to eq(rows.length)

        contact = arabic_data_import.account.contacts.first
        expect(contact.name).to eq('أحمد علي')
        expect(contact.additional_attributes['company']).to eq('شركة الاختبار')
      end
    end

    context 'when the data contains existing records' do
      let(:existing_data) do
        [
          %w[id name email phone_number company],
          ['1', 'Clarice Uzzell', 'cuzzell0@mozilla.org', '918080808080', 'Acmecorp'],
          ['2', 'Marieann Creegan', 'mcreegan1@cornell.edu', '+918080808081', 'Acmecorp'],
          ['3', 'Nancey Windibank', 'nwindibank2@bluehost.com', '+918080808082', 'Acmecorp']
        ]
      end
      let(:existing_data_import) { create(:data_import, import_file: generate_xlsx_file(existing_data)) }
      let(:rows) { xlsx_rows(existing_data_import.import_file.download) }

      context 'when the existing record has an email in import data' do
        it 'updates the existing record with new data' do
          contact = Contact.create!(email: rows[0]['email'], account_id: existing_data_import.account_id)
          expect(contact.reload.phone_number).to be_nil

          described_class.perform_now(existing_data_import)
          expect(existing_data_import.account.contacts.count).to eq(rows.length)
          contact = Contact.from_email(rows[0]['email'])
          expect(contact).to be_present
          expect(contact.phone_number).to eq("+#{rows[0]['phone_number']}")
          expect(contact.name).to eq((rows[0]['name']).to_s)
          expect(contact.additional_attributes['company']).to eq((rows[0]['company']).to_s)
        end
      end

      context 'when the existing record has a phone_number in import data' do
        it 'updates the existing record with new data' do
          contact = Contact.create!(account_id: existing_data_import.account_id, phone_number: rows[1]['phone_number'])
          expect(contact.reload.email).to be_nil

          described_class.perform_now(existing_data_import)
          expect(existing_data_import.account.contacts.count).to eq(rows.length)

          contact = Contact.find_by(phone_number: "+#{rows[0]['phone_number']}")
          expect(contact).to be_present
          expect(contact.email).to eq(rows[0]['email'])
          expect(contact.name).to eq((rows[0]['name']).to_s)
          expect(contact.additional_attributes['company']).to eq((rows[0]['company']).to_s)
        end
      end

      context 'when the existing record has both email and phone_number in import data' do
        it 'skips importing the records' do
          phone_contact = Contact.create!(account_id: existing_data_import.account_id, phone_number: rows[1]['phone_number'])
          email_contact = Contact.create!(account_id: existing_data_import.account_id, email: rows[1]['email'])

          described_class.perform_now(existing_data_import)
          expect(phone_contact.reload.email).to be_nil
          expect(email_contact.reload.phone_number).to be_nil
          expect(existing_data_import.total_records).to eq(rows.length)
          expect(existing_data_import.processed_records).to eq(rows.length - 1)
        end
      end
    end

    context 'when the Excel file is invalid' do
      let(:invalid_workbook_content) { 'not an excel workbook' }

      before do
        temp_file = Tempfile.new(['invalid_contacts', '.xlsx'])
        temp_file.binmode
        temp_file.write(invalid_workbook_content)
        temp_file.rewind

        import_file_double = instance_double(ActiveStorage::Blob)
        allow(data_import).to receive(:import_file).and_return(import_file_double)
        allow(import_file_double).to receive(:open).and_yield(temp_file)
      end

      it 'does not import any data and marks the import as failed' do
        expect { described_class.perform_now(data_import) }
          .to change { data_import.reload.status }.from('pending').to('failed')
      end
    end
  end
end
