class MessagePolicy < ApplicationPolicy
  def destroy?
    @account_user.administrator?
  end
end
