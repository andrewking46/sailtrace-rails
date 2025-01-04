module Authorization
  private

  def ensure_can_administer
    head :forbidden unless Current.user.is_admin?
  end
end
