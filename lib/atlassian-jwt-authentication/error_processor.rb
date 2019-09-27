module AtlassianJwtAuthentication
  module ErrorProcessor
    protected

    def render_forbidden
      head(:forbidden)
    end

    def render_payment_required
      head(:payment_required)
    end

    def render_unauthorized
      head(:unauthorized)
    end
  end
end