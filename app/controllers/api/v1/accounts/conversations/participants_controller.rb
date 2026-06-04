class Api::V1::Accounts::Conversations::ParticipantsController < Api::V1::Accounts::Conversations::BaseController
  before_action :check_admin_authorization?, only: [:destroy]

  def show
    @participants = @conversation.conversation_participants
  end

  def create
    ActiveRecord::Base.transaction do
      @participants = participants_to_be_added_ids.map { |user_id| @conversation.conversation_participants.find_or_create_by(user_id: user_id) }
    end
  end

  def update
    # Agents may add participants and remove themselves (collaboration);
    # removing another participant is admin-only.
    check_admin_authorization? if removing_other_participants?

    ActiveRecord::Base.transaction do
      participants_to_be_added_ids.each { |user_id| @conversation.conversation_participants.find_or_create_by(user_id: user_id) }
      participants_to_be_removed_ids.each { |user_id| @conversation.conversation_participants.find_by(user_id: user_id)&.destroy }
    end
    @participants = @conversation.conversation_participants
    render action: 'show'
  end

  def destroy
    ActiveRecord::Base.transaction do
      params[:user_ids].map { |user_id| @conversation.conversation_participants.find_by(user_id: user_id)&.destroy }
    end
    head :ok
  end

  private

  def participants_to_be_added_ids
    params[:user_ids] - current_participant_ids
  end

  def participants_to_be_removed_ids
    current_participant_ids - params[:user_ids]
  end

  def removing_other_participants?
    participants_to_be_removed_ids.any? { |user_id| user_id != Current.user.id }
  end

  def current_participant_ids
    @current_participant_ids ||= @conversation.conversation_participants.pluck(:user_id)
  end
end
