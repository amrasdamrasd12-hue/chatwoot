require 'rails_helper'

describe ContactInboxWithContactBuilder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, email: 'xyc@example.com', phone_number: '+23423424123', account: account, identifier: '123') }
  let(:existing_contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }

  describe '#perform' do
    it 'doesnot create contact if it already exist with source id' do
      contact_inbox = described_class.new(
        source_id: existing_contact_inbox.source_id,
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: '+1234567890',
          email: 'testemail@example.com'
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'creates contact if contact doesnot exist with source id' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: '+1234567890',
          email: 'testemail@example.com',
          custom_attributes: { test: 'test' }
        }
      ).perform

      expect(contact_inbox.contact.id).not_to eq(contact.id)
      expect(contact_inbox.contact.name).to eq('Contact')
      expect(contact_inbox.contact.custom_attributes).to eq({ 'test' => 'test' })
      expect(contact_inbox.inbox_id).to eq(inbox.id)
    end

    it 'doesnot create contact if it already exist with identifier' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          identifier: contact.identifier,
          phone_number: contact.phone_number,
          email: 'testemail@example.com'
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'doesnot create contact if it already exist with email' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: '+1234567890',
          email: contact.email
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'doesnot create contact when an uppercase email is passed for an already existing contact email' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: '+1234567890',
          email: contact.email.upcase
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    it 'doesnot create contact if it already exist with phone number' do
      contact_inbox = described_class.new(
        source_id: '123456',
        inbox: inbox,
        contact_attributes: {
          name: 'Contact',
          phone_number: contact.phone_number,
          email: 'testemail@example.com'
        }
      ).perform

      expect(contact_inbox.contact.id).to be(contact.id)
    end

    context 'when contact has secondary phones in custom_customer_mobile_numbers' do
      let(:secondary_phone) { '+201009999999' }
      let!(:contact_with_secondary) do
        create(:contact, account: account, additional_attributes: {
                 'custom_customer_mobile_numbers' => [
                   { 'phone' => secondary_phone, 'phone_type' => 'Mobile', 'default_phone' => false }
                 ]
               })
      end

      it 'finds contact by exact secondary phone match' do
        contact_inbox = described_class.new(
          source_id: '201009999999',
          inbox: inbox,
          contact_attributes: { phone_number: secondary_phone }
        ).perform

        expect(contact_inbox.contact.id).to eq(contact_with_secondary.id)
      end

      it 'finds contact when incoming phone lacks + prefix (last-10-digits match)' do
        contact_inbox = described_class.new(
          source_id: '201009999999',
          inbox: inbox,
          contact_attributes: { phone_number: '+201009999999' }
        ).perform

        # stored "+201009999999", incoming "+201009999999" → last 10 = "1009999999" ✓
        expect(contact_inbox.contact.id).to eq(contact_with_secondary.id)
      end

      it 'creates a contact_inbox with the new source_id so future lookups are instant' do
        described_class.new(
          source_id: '201009999999',
          inbox: inbox,
          contact_attributes: { phone_number: secondary_phone }
        ).perform

        expect(ContactInbox.find_by(source_id: '201009999999', inbox: inbox)).to be_present
      end

      it 'creates a new contact when phone is not in any secondary array' do
        contact_inbox = described_class.new(
          source_id: '201007777777',
          inbox: inbox,
          contact_attributes: { phone_number: '+201007777777', name: 'Stranger' }
        ).perform

        expect(contact_inbox.contact.id).not_to eq(contact_with_secondary.id)
        expect(contact_inbox.contact.name).to eq('Stranger')
      end
    end

    context 'when contact has secondary phones in legacy flat fields' do
      let!(:legacy_contact) do
        create(:contact, account: account, additional_attributes: {
                 'phone_secondary' => '+201008888888',
                 'phone_alternative' => '+201006666666'
               })
      end

      it 'finds contact via legacy phone_secondary field' do
        contact_inbox = described_class.new(
          source_id: '201008888888',
          inbox: inbox,
          contact_attributes: { phone_number: '+201008888888' }
        ).perform

        expect(contact_inbox.contact.id).to eq(legacy_contact.id)
      end

      it 'finds contact via legacy phone_alternative field' do
        contact_inbox = described_class.new(
          source_id: '201006666666',
          inbox: inbox,
          contact_attributes: { phone_number: '+201006666666' }
        ).perform

        expect(contact_inbox.contact.id).to eq(legacy_contact.id)
      end
    end

    it 'reuses contact if it exists with the same source_id in a Facebook inbox when creating for Instagram inbox' do
      instagram_source_id = '123456789'

      # Create a Facebook page inbox with a contact using the same source_id
      facebook_inbox = create(:inbox, channel_type: 'Channel::FacebookPage', account: account)
      facebook_contact = create(:contact, account: account)
      facebook_contact_inbox = create(:contact_inbox, contact: facebook_contact, inbox: facebook_inbox, source_id: instagram_source_id)

      # Create an Instagram inbox
      instagram_inbox = create(:inbox, channel_type: 'Channel::Instagram', account: account)

      # Try to create a contact inbox with same source_id for Instagram
      contact_inbox = described_class.new(
        source_id: instagram_source_id,
        inbox: instagram_inbox,
        contact_attributes: {
          name: 'Instagram User',
          email: 'instagram_user@example.com'
        }
      ).perform

      # Should reuse the existing contact from Facebook
      expect(contact_inbox.contact.id).to eq(facebook_contact.id)
      # Make sure the contact inbox is not the same as the Facebook contact inbox
      expect(contact_inbox.id).not_to eq(facebook_contact_inbox.id)
      expect(contact_inbox.inbox_id).to eq(instagram_inbox.id)
    end
  end
end
